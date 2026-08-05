{ pkgs, ... }:
let
  src = pkgs.writeTextDir "skills/external-skill/SKILL.md" ''
    # Mock Skill
  '';
in
{
  programs.github-copilot-cli = {
    enable = true;
    package = null;
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
    assertFileContent home-files/.copilot/skills/typed-dir/SKILL.md \
      "${src}/skills/external-skill/SKILL.md"
    assertFileContent home-files/.copilot/skills/typed-file/SKILL.md \
      "${src}/skills/external-skill/SKILL.md"
  '';
}
