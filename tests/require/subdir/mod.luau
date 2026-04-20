print("Subdir module loaded!"); 
local util = require("util") 
return { 
    greet = function(name) 
        return "Hello, " .. name .. "! sum: " .. util.add(1, 2) 
    end 
}
