-- Test @self/../
local mod2 = require("pastadoscript2")
print("mod2.hello = " .. mod2.hello)
return {
    module2 = mod2,
    hello = "from pastadoscript"
}
