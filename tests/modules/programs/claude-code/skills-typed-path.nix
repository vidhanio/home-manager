{ pkgs, ... }:

let
  src = pkgs.writeTextDir "claude-plugin/skills/beads/SKILL.md" ''
    # Beads
  '';
in
{
  programs.claude-code = {
    enable = true;
    skills = {
      typed-dir = {
        path = "${src}/claude-plugin/skills/beads";
        type = "directory";
      };
      typed-file = {
        path = "${src}/claude-plugin/skills/beads/SKILL.md";
        type = "file";
      };
    };
  };

  nmt.script = ''
    assertFileContent home-files/.claude/skills/typed-dir/SKILL.md \
      "${src}/claude-plugin/skills/beads/SKILL.md"
    assertFileContent home-files/.claude/skills/typed-file/SKILL.md \
      "${src}/claude-plugin/skills/beads/SKILL.md"
  '';
}
