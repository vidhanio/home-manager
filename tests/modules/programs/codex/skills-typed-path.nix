{ pkgs, ... }:
let
  src = pkgs.writeTextDir "skills/external-skill/SKILL.md" ''
    ---
    name: external-skill
    description: Store path skill fixture.
    ---

    # External Skill
  '';
in
{
  programs.codex = {
    enable = true;
    skills = {
      typed-dir = {
        path = "${src}/skills/external-skill";
        type = "directory";
      };
      typed-file = {
        path = "${src}/skills/external-skill/SKILL.md";
        type = "file";
      };
    };
  };

  nmt.script = ''
    assertFileContent home-files/.codex/skills/typed-dir/SKILL.md \
      "${src}/skills/external-skill/SKILL.md"
    assertFileContent home-files/.codex/skills/typed-file/SKILL.md \
      "${src}/skills/external-skill/SKILL.md"
  '';
}
