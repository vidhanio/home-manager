{ pkgs, ... }:

let
  src = pkgs.writeTextDir "skills/external-skill/SKILL.md" ''
    # Mock Skill
  '';
in
{
  programs.opencode = {
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
    assertFileContent home-files/.config/opencode/skills/typed-dir/SKILL.md \
      "${src}/skills/external-skill/SKILL.md"
    assertFileContent home-files/.config/opencode/skills/typed-file/SKILL.md \
      "${src}/skills/external-skill/SKILL.md"
  '';
}
