Plan A — Runtime-embedded Luau Error Signaling

- Objetivo
  - dlopen e require devolvem Luau errors com localização (arquivo:linha) para uso com pcall, sem wrappers de teste externos nem migração para mlua Module.

- Abordagem
  - Sinalizar falhas no boundary Rust-Lua retornando nil + mensagem (dois valores) para Lua.
  - Embutir wrappers no runtime que transformam esse estado em Luau errors com localização usando debug.getinfo.
  - Injetar uma flag de debug LUKS_DEBUG_FORCE_FAIL para forçar falhas durante debugging, simulando cenários de erro controlados.

- API exposta no runtime
  - luks_safe_dlopen(path) -> retorna o módulo ou levanta Luau error com localização
  - luks_safe_require(path) -> idem para require

- Fluxo de depuração
  - Defina LUKS_DEBUG_FORCE_FAIL=1 para ativar falha simulada no wrapper de runtime.
  - Use pcall para capturar o Luau error com localização, ajudando o debug de mensagens de erro ricos.

- Testes
  - Edge cases: caminhos com espaços, caminhos relativos, >= 2 cenários de falha (missing lib, path inválido).
  - Casos positivos: carrega testmodule via path relativo correto.
  - Não usar wrappers de teste externos; tudo é gerado pelo runtime.

- Observações
  - Se debug info não estiver disponível em algum ambiente, manteremos uma fallback simples com arquivo/linha básica.
