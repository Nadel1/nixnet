{
  writeShellScriptBin,
  name ? "hello",
  audience ? "world",
}:
writeShellScriptBin "hello" ''
  echo "Hello, ${audience}!"
''