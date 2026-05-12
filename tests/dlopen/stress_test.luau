local my_module = dlopen("@self/../../target/debug/testmodule")

print("Iniciando Teste de Stress (300.000 chamadas)")
local start_time = os.clock()

local success_count = 0

-- 1. Teste Sincrono Massivo
for i = 1, 300000 do
    local res = my_module.hello()
    if res == "Greetings from Rust via VTable!" then
        success_count += 1
    end
end

local sync_time = os.clock()
print(string.format("Teste Sincrono: %d chamadas concluidas em %.4f segundos", success_count, sync_time - start_time))

-- 2. Teste Assincrono (Scheduler Stress)
print("Iniciando Teste Assincrono com task.spawn (300 tasks x 1000 chamadas)...")
local async_success = 0
local expected_async = 300 * 1000

for i = 1, 300 do
    task.spawn(function()
        for j = 1, 1000 do
            local res = my_module.hello()
            if res == "Greetings from Rust via VTable!" then
                async_success += 1
            end
        end
    end)
end

-- Vamos colocar um delay ou yield pra garantir que todas rodem
task.wait(0.5)

local end_time = os.clock()
print(string.format("Teste Assincrono: %d chamadas concluidas em %.4f segundos", async_success, end_time - sync_time))
print("Teste de stress finalizado sem falhas de memoria!")
