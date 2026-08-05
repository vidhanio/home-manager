{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    ;

  cfg = config.programs.crush;

  jsonFormat = pkgs.formats.json { };

  # Crush expands `$VAR` and `$(command)` in the MCP server command, args, env,
  # url, and headers, so file references become a command substitution instead
  # of a wrapper script.
  toCrushServer =
    server:
    lib.hm.mcp.transformMcpServer {
      inherit server;
      exclude = [ "enabled" ];
      extraTransforms = [ lib.hm.mcp.addType ];
      mkFileRef = path: "$(cat ${lib.escapeShellArg path})";
    }
    // lib.optionalAttrs ((server.enabled or null) == false || (server.disabled or false)) {
      disabled = true;
    };

  transformedMcpServers = lib.optionalAttrs (cfg.enableMcpIntegration && config.programs.mcp.enable) (
    lib.mapAttrs (_: toCrushServer) config.programs.mcp.servers
  );

  mcpServers = transformedMcpServers // (cfg.settings.mcp or { });

  settings = cfg.settings // lib.optionalAttrs (mcpServers != { }) { mcp = mcpServers; };

  skills = if lib.isAttrs cfg.skills then cfg.skills else { };
in
{
  meta.maintainers = [ lib.maintainers.vidhanio ];

  options.programs.crush = {
    enable = mkEnableOption "Crush, Charm's coding agent for the terminal";

    package = mkPackageOption pkgs "crush" { nullable = true; };

    enableMcpIntegration = mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to integrate the MCP servers config from
        {option}`programs.mcp.servers` into
        {option}`programs.crush.settings.mcp`.

        Note: Settings defined in {option}`programs.mcp.servers` are merged
        with {option}`programs.crush.settings.mcp`, with Crush settings taking
        precedence.
      '';
    };

    settings = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = literalExpression ''
        {
          models.large = {
            model = "claude-sonnet-4-20250514";
            provider = "anthropic";
          };
          providers.deepseek = {
            type = "openai-compat";
            base_url = "https://api.deepseek.com/v1";
            api_key = "$(cat /run/secrets/deepseek-api-key)";
            models = [
              {
                id = "deepseek-chat";
                name = "Deepseek V3";
              }
            ];
          };
          lsp.nix.command = "nil";
          options.disabled_tools = [ "sourcegraph" ];
          permissions.allowed_tools = [ "view" ];
        }
      '';
      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/crush/crush.json`.
        See <https://github.com/charmbracelet/crush> for the documentation.

        Crush expands `$VAR` and `$(command)` in configuration values, so
        secrets can be read at startup instead of being written to the Nix
        store.

        Note, `"$schema": "https://charm.land/crush.json"` is automatically
        added to the configuration.
      '';
    };

    skills = lib.hm.paths.mkSkillsOption {
      name = "Crush";
      dir = "$XDG_CONFIG_HOME/crush/skills";
      example = literalExpression ''
        {
          git-release = '''
            ---
            name: git-release
            description: Create consistent releases and changelogs
            ---

            ## What I do

            - Draft release notes from merged PRs
            - Propose a version bump
          ''';

          # A skill can also be a directory containing SKILL.md and other files.
          data-analysis = ./skills/data-analysis;
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !lib.hm.strings.isPathLike cfg.skills || lib.hm.paths.isDirectory cfg.skills;
        message = "`programs.crush.skills` must be a directory when set to a path";
      }
    ];

    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile = {
      "crush/crush.json" = mkIf (settings != { }) {
        source = jsonFormat.generate "crush.json" (
          {
            "$schema" = "https://charm.land/crush.json";
          }
          // settings
        );
      };

      "crush/skills" = mkIf (lib.hm.strings.isPathLike cfg.skills) {
        source = cfg.skills;
        recursive = true;
      };
    }
    // lib.hm.paths.mkSkillEntries { dir = "crush/skills"; } skills;
  };
}
