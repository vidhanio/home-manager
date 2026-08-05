{ lib }:

let
  inherit (lib.hm.strings) isPathLike;

  /*
    Whether `content` refers to a directory rather than a file or inline
    content.

    Answering this realizes the path, so content backed by a derivation that
    has not been built yet is built during evaluation
    (import-from-derivation).

    Type: isDirectory :: (Path | String | Derivation) -> Bool
  */
  isDirectory = content: isPathLike content && lib.pathIsDirectory content;

  /*
    A `home.file`-style entry for content that is either a path to a file or
    inline text.

    Type: mkSourceEntry :: (Path | String | Derivation) -> AttrSet

    Example:
      mkSourceEntry ./skill.md
      => { source = ./skill.md; }

      mkSourceEntry "inline content"
      => { text = "inline content"; }
  */
  mkSourceEntry = content: if isPathLike content then { source = content; } else { text = content; };

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
    The type of a named set of content entries, or of a single directory
    holding one entry per name.

    Type: contentSetType :: OptionType
  */
  contentSetType = lib.types.either (lib.types.attrsOf contentType) lib.types.path;

  /*
    An option holding a named set of content entries, such as skills or
    agents. Every program declaring one uses the same type and default, so
    only the documentation differs between them.

    Type: mkContentSetOption :: { description, example } -> Option
  */
  mkContentSetOption =
    { description, example }:
    lib.mkOption {
      type = contentSetType;
      default = { };
      inherit description example;
    };
in
{
  inherit
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
          source = content;
          recursive = true;
        }
      else
        lib.nameValuePair "${dir}/${name}/SKILL.md" (mkSourceEntry content)
    );
}
