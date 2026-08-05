# Archived Claude skills

These skills moved to the team plugin at `measured-fi/claude-plugins`, so they're no
longer deployed to `~/.claude/skills/`. Kept here for reference only.

Install the plugin versions instead:

```sh
/plugin marketplace add measured-fi/claude-plugins
/plugin install pr-narrative@measured-tools
```

They're namespaced once installed: `/pr-narrative:pr-narrative-review` and
`/pr-narrative:publish-narrative`.

The copies in this folder are the last standalone versions. They differ from the
plugin in one way: they reference the renderer script by an absolute `~/.claude/`
path, which the plugin replaces with `${CLAUDE_PLUGIN_ROOT}`. Don't copy these
back into `dot_claude/skills/` without reverting that.
