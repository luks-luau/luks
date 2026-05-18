--!strict
local h = require("../../helpers")
local FS = require("../../../luks-std/fs")

return function(expect)
    h.suite("FS: Directory Management", function()
        h.test("create_dir and remove_dir", function()
            local path = "test_single_dir"
            FS.create_dir(path):expect("create_dir failed")
            expect.true_(FS.metadata(path):expect(""):is_dir())
            
            FS.remove_dir(path):expect("remove_dir failed")
            local _, ok = FS.metadata(path):Wait()
            expect.false_(ok, "dir should be gone")
        end)

        h.test("recursive create and remove", function()
            local path = "test_nested_a/b/c"
            FS.create_dir_all(path):expect("create_dir_all failed")
            expect.true_(FS.metadata(path):expect(""):is_dir())
            
            FS.remove_dir_all("test_nested_a"):expect("remove_dir_all failed")
            local _, ok = FS.metadata("test_nested_a"):Wait()
            expect.false_(ok, "nested root should be gone")
        end)
    end)

    h.suite("FS: Metadata and Path Utilities", function()
        h.test("metadata snapshot properties", function()
            local path = "test_meta_props.txt"
            FS.write(path, "data"):expect("")
            
            local meta = FS.metadata(path):expect("metadata failed")
            expect.eq(meta:len(), 4)
            expect.eq(meta:is_file(), true)
            expect.eq(meta:is_dir(), false)
            expect.type_(meta:modified(), "number")
            expect.type_(meta:created(), "number")
            expect.type_(meta:accessed(), "number")
            
            local ft = meta:file_type()
            expect.eq(ft:is_file(), true)
            
            local perms = meta:permissions()
            expect.type_(perms:readonly(), "boolean")
            
            FS.remove_file(path):expect("")
        end)

        h.test("canonicalize and paths", function()
            local path = "test_canon.txt"
            FS.write(path, ""):expect("")
            
            local abs = FS.canonicalize(path):expect("canonicalize failed")
            expect.true_(string.find(abs, "test_canon.txt") ~= nil)
            
            FS.remove_file(path):expect("")
        end)

        h.test("hard links and read_link", function()
            local src = "test_link_src.txt"
            local dst = "test_link_dst.txt"
            FS.write(src, "shared"):expect("")
            
            FS.hard_link(src, dst):expect("hard_link failed")
            expect.eq(FS.read_to_string(dst):expect(""), "shared")
            
            -- Changing one should change the other (same inode)
            FS.write(src, "modified"):expect("")
            expect.eq(FS.read_to_string(dst):expect(""), "modified")
            
            FS.remove_file(src):expect("")
            FS.remove_file(dst):expect("")
        end)
    end)
end
