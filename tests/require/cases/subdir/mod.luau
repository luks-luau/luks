print("Subdir module loaded!")

local helper = require("./helper")

return {
    add = function(a, b)
        return a + b
    end,
    greet = function(name)
        return "Hello, " .. name .. "!"
    end,
    util = helper,
    counter = 0
}
