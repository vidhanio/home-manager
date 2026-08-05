{ lib }:

let
  inherit (lib.hm.strings) isPathLike;

  /*
    A path that states whether it points at a file or at a directory.

    Type: typedPathType :: OptionType
  */
  typedPathType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.path;
        description = "Path to the file or directory holding the content.";
      };

      type = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "file"
            "directory"
          ]
        );
        default = null;
        example = "directory";
        description = ''
          Whether {option}`path` points at a file or at a directory.

          When this is `null`, Home Manager inspects {option}`path` to find
          out, which realizes it. A path that comes from a derivation is then
          built during evaluation (import-from-derivation). State the type to
          avoid that.
        '';
      };
    };
  };

  /*
    Whether a value states a path together with its type, rather than being a
    bare path. Derivations are attribute sets as well, so they are excluded.

    Type: isTypedPath :: Value -> Bool
  */
  isTypedPath = value: lib.isAttrs value && value ? path && !lib.isDerivation value;

  /*
    Whether `content` refers to a path at all, rather than to inline content.

    Type: isPath :: Value -> Bool
  */
  isPath = content: isTypedPath content || isPathLike content;

  /*
    The path `content` refers to, whether it is stated directly or through a
    typed path.

    Type: getPath :: Value -> (Path | String | Derivation)
  */
  getPath = content: if isTypedPath content then content.path else content;

  /*
    Whether `content` refers to a directory rather than a file or inline
    content.

    A typed path that states its type is answered from that alone. Any other
    path has to be realized to be inspected, so content backed by a derivation
    that has not been built yet is built during evaluation
    (import-from-derivation).

    Type: isDirectory :: Value -> Bool
  */
  isDirectory =
    content:
    if isTypedPath content && content.type or null != null then
      content.type == "directory"
    else
      let
        path = getPath content;
      in
      isPathLike path && lib.pathIsDirectory path;

  /*
    A `home.file`-style entry for content that is either a path to a file or
    inline text.

    Type: mkSourceEntry :: Value -> AttrSet

    Example:
      mkSourceEntry ./skill.md
      => { source = ./skill.md; }

      mkSourceEntry "inline content"
      => { text = "inline content"; }
  */
  mkSourceEntry =
    content: if isPath content then { source = getPath content; } else { text = content; };

  /*
    The type of a single piece of content that is either inline text or a path
    to a file or a directory.

    Type: contentType :: OptionType
  */
  contentType = lib.types.oneOf [
    lib.types.lines
    lib.types.path
  ];

  /*
    The type of a single skill. Only skills tell a file apart from a
    directory, so only they accept a typed path.

    Type: skillContentType :: OptionType
  */
  skillContentType = lib.types.oneOf [
    lib.types.lines
    lib.types.path
    typedPathType
  ];

  /*
    The type of a named set of content entries, or of a single directory
    holding one entry per name.

    Type: contentSetType :: OptionType
  */
  contentSetType = lib.types.either (lib.types.attrsOf contentType) lib.types.path;

  /*
    The `contentSetType` of a set of skills.

    Type: skillsSetType :: OptionType
  */
  skillsSetType = lib.types.either (lib.types.attrsOf skillContentType) lib.types.path;

  /*
    An option holding a named set of content entries, such as skills or
    agents. Every program declaring one uses the same type and default, so
    only the documentation differs between them.

    Type: mkContentSetOption :: { description, example, type? } -> Option
  */
  mkContentSetOption =
    {
      description,
      example,
      type ? contentSetType,
    }:
    lib.mkOption {
      default = { };
      inherit type description example;
    };
in
{
  inherit
    typedPathType
    isTypedPath
    isPath
    skillContentType
    skillsSetType
    getPath
    isDirectory
    mkSourceEntry
    contentType
    contentSetType
    mkContentSetOption
    ;

  /*
    A skills option. Skills work the same way in every program that supports
    them, so the documentation is generated from what actually differs: the
    program's `name` and the `dir` its skills live in.

    Set `skillMustBeDirectory` for a program that loads a skill only from a
    directory it symlinks whole, so that content which is not already a
    directory has to be wrapped in a generated one. `extraDescription` and a
    reference to `docsUrl` are appended.

    Type: mkSkillsOption ::
      { name, dir, skillMustBeDirectory?, docsUrl?, extraDescription?,
        example }
      -> Option
  */
  mkSkillsOption =
    {
      name,
      dir,
      skillMustBeDirectory ? false,
      docsUrl ? null,
      extraDescription ? "",
      example,
    }:
    let
      entryTarget =
        if skillMustBeDirectory then
          "a generated skill directory at {file}`${dir}/<name>/`"
        else
          "{file}`${dir}/<name>/SKILL.md`";

      directoryTarget =
        if skillMustBeDirectory then
          "symlinks {file}`${dir}/<name>/` to that directory"
        else
          "creates {file}`${dir}/<name>/` with all files";

      pathTarget =
        if skillMustBeDirectory then
          "Each top-level skill entry is symlinked into {file}`${dir}/`, leaving {file}`${dir}/` itself a normal directory so unmanaged skills can coexist."
        else
          "The directory is symlinked to {file}`${dir}/`.";
    in
    mkContentSetOption {
      inherit example;
      type = skillsSetType;
      description = ''
        Custom skills for ${name}.

        This option can be either:
        - An attribute set defining skills
        - A path to a directory containing skill folders

        If an attribute set is used, the attribute name becomes the skill
        directory name, and the value is either:
        - Inline content as a string (creates ${entryTarget})
        - A path to a file (creates ${entryTarget})
        - A path to a directory (${directoryTarget})

        A path can state which of the two it is, as
        `{ path = ./skills/grill-me/SKILL.md; type = "file"; }` or
        `{ path = ./skills/grill-me; type = "directory"; }`. Home Manager
        otherwise has to inspect it, which builds a path that comes from a
        derivation during evaluation (import-from-derivation).

        This also accepts Nix store paths, for example a skill directory from
        a package.

        If a path is used, it is expected to contain one folder per skill
        name, each containing a {file}`SKILL.md`. ${pathTarget}
      ''
      + lib.optionalString (extraDescription != "") "\n${extraDescription}"
      + lib.optionalString (docsUrl != null) "\nSee <${docsUrl}> for the documentation.\n";
    };

  /*
    `home.file`/`xdg.configFile` entries for a set of skills, keyed by skill
    name.

    Each attribute name becomes a skill directory below `dir`. A value that is
    a directory is linked as that skill directory itself; any other value
    provides the skill's {file}`SKILL.md`.

    Type: mkSkillEntries :: { dir } -> AttrSet -> AttrSet

    Example:
      mkSkillEntries { dir = "prog/skills"; } {
        inline = "content";
        bundled = ./data-analysis;
      }
      => {
        "prog/skills/inline/SKILL.md" = { text = "content"; };
        "prog/skills/bundled" = { source = ./data-analysis; recursive = true; };
      }
  */
  mkSkillEntries =
    { dir }:
    lib.mapAttrs' (
      name: content:
      if isDirectory content then
        lib.nameValuePair "${dir}/${name}" {
          source = getPath content;
          recursive = true;
        }
      else
        lib.nameValuePair "${dir}/${name}/SKILL.md" (mkSourceEntry content)
    );
}
