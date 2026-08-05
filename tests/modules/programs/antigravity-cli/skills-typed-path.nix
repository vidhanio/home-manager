{ pkgs, ... }:
let
  src = pkgs.writeTextDir "skills/external-skill/SKILL.md" ''
    # Mock Skill
  '';
in
{
  programs.antigravity-cli = {
    enable = true;
    package = pkgs.writeShellScriptBin "antigravity-cli" "";
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
    assertFileContent home-files/.gemini/antigravity-cli/skills/typed-dir/SKILL.md \
      "${src}/skills/external-skill/SKILL.md"
    assertFileContent home-files/.gemini/antigravity-cli/skills/typed-file/SKILL.md \
      "${src}/skills/external-skill/SKILL.md"
  '';
}
