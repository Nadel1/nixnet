{
  writeShellScriptBin,
  name ? "hello",
  audience ? "world",
}:
writeShellScriptBin "${name}" ''
  echo "Hello, ${audience}!"
''