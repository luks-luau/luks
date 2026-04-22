-- Helper module for dlopen object passing tests
-- Provides functions to receive, store, and pass objects

local stored_object = nil

local receiver = {}

-- Store an object for later verification
function receiver.store(obj)
    stored_object = obj
    return true
end

-- Call hello method on the passed object
function receiver.call_hello(obj)
    if obj and obj.hello then
        return obj.hello()
    end
    return nil
end

-- Pass through an object (returns it unchanged)
function receiver.pass_through(obj)
    return obj
end

-- Verify the passed object matches the stored one
function receiver.verify_same(obj)
    return obj == stored_object
end

-- Get the stored object
function receiver.get_stored()
    return stored_object
end

return receiver
