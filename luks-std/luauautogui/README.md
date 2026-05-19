# `luauautogui` — Automação de Interface Gráfica para Luau

O módulo `luauautogui` é uma biblioteca nativa para automação de GUI no ecossistema `luks-luau` inspirada diretamente pela biblioteca Rust **`rustautogui` de DavorMar** (e `PyAutoGUI` do Python).

## 🚀 Recursos
- **Controle de Mouse:** Movimento suave interpolado temporalmente (`move_mouse_to_pos`), arrastamento (`drag_mouse_to_pos`), cliques específicos de botões (`LEFT`, `RIGHT`, `MIDDLE`) e rolagens (`scroll_up`/`scroll_down`).
- **Controle de Teclado:** Digitação de strings (`keyboard_input`), teclas de comando especial (`keyboard_command`) e atalhos combinados de teclas simultâneas (`keyboard_multi_key`).
- **Captura e Reconhecimento de Tela:** Captura de screenshots nativos (`save_screenshot`) e template matching de imagem em alta velocidade via algoritmo de correlação cruzada otimizado em Rust (`find_image_on_screen`).

---

## 🛠️ API e Uso Completo

### Inicialização
```luau
local luauautogui = require("@luks/luauautogui")
local gui = luauautogui.new(true) -- Instancia com debug log ativo
```

### Funções de Tela e Mouse
```luau
-- 1. Dimensão da Tela
local width, height = gui:get_screen_size()
print("Resolução:", width, "x", height)

-- 2. Ler posição do mouse (Retorna uma TaskFuture)
local pos = gui:get_mouse_position():Wait()
print("Mouse X, Y:", pos.x, pos.y)

-- 3. Mover mouse suavemente em 1.5 segundos
gui:move_mouse_to_pos(500, 500, 1.5):Wait()

-- 4. Clique e Rotação
gui:click_down("LEFT"):Wait()
gui:click_up("LEFT"):Wait()
gui:scroll_up(3):Wait()   -- Rola para cima 3 cliques
gui:scroll_down(1):Wait() -- Rola para baixo 1 clique
```

### Teclado e Atalhos
```luau
-- 1. Digitação simples
gui:keyboard_input("hello world", false):Wait()

-- 2. Digitação com Shift pressionado
gui:keyboard_input("uppercase text", true):Wait()

-- 3. Tecla de Comando Especial
gui:keyboard_command("enter"):Wait()

-- 4. Atalhos de múltiplas teclas (ex: CTRL + ALT + DEL ou CTRL + C)
gui:keyboard_multi_key("control", "alt", "delete"):Wait()
```

### Captura de Tela e Reconhecimento de Imagens (Template Matching)
```luau
-- 1. Capturar Tela inteira e salvar em arquivo BMP
gui:save_screenshot("C:\\captura.bmp"):Wait()

-- 2. Carregar uma Imagem de Template (BMP) para busca
gui:prepare_template_from_file("C:\\template.bmp"):Wait()

-- 3. Procurar a imagem na tela (Threshold de confiança = 0.9)
local match = gui:find_image_on_screen(0.9):Wait()
if match then
    print("Imagem encontrada no centro:", match.x, match.y)
    
    -- 4. Encontrar e já mover o mouse suavemente
    gui:find_image_on_screen_and_move_mouse(0.9, 1.0):Wait()
else
    print("Imagem não encontrada")
end
```
