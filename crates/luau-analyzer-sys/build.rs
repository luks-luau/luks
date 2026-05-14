use std::path::PathBuf;

fn main() {
    let luau_dir = PathBuf::from("luau");

    // =========================================================================
    // Cargo Rerun Triggers (Evita recompilações desnecessárias)
    // =========================================================================
    // Garante que o build.rs só rode se o próprio script, o shim ou a pasta do Luau mudarem
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=src/shim.cpp");

    // Listas de arquivos fonte para rastreamento fino pelo Cargo
    let common_sources = [
        "Common/src/BytecodeWire.cpp",
        "Common/src/StringUtils.cpp",
        "Common/src/TimeTrace.cpp",
    ];

    let ast_sources = [
        "Ast/src/Allocator.cpp",
        "Ast/src/Ast.cpp",
        "Ast/src/Confusables.cpp",
        "Ast/src/Cst.cpp",
        "Ast/src/Lexer.cpp",
        "Ast/src/Location.cpp",
        "Ast/src/Parser.cpp",
        "Ast/src/PrettyPrinter.cpp",
    ];

    let bytecode_sources = [
        "Bytecode/src/BytecodeBuilder.cpp",
        "Bytecode/src/BytecodeGraph.cpp",
    ];

    let compiler_sources = [
        "Compiler/src/Compiler.cpp",
        "Compiler/src/Builtins.cpp",
        "Compiler/src/BuiltinFolding.cpp",
        "Compiler/src/ConstantFolding.cpp",
        "Compiler/src/CostModel.cpp",
        "Compiler/src/TableShape.cpp",
        "Compiler/src/Types.cpp",
        "Compiler/src/ValueTracking.cpp",
        "Compiler/src/lcode.cpp",
    ];

    let config_sources = [
        "Config/src/Config.cpp",
        "Config/src/LinterConfig.cpp",
        "Config/src/LuauConfig.cpp",
    ];

    let analysis_sources = [
        "Analysis/src/Anyification.cpp",
        "Analysis/src/ApplyTypeFunction.cpp",
        "Analysis/src/AstJsonEncoder.cpp",
        "Analysis/src/AstQuery.cpp",
        "Analysis/src/AstUtils.cpp",
        "Analysis/src/Autocomplete.cpp",
        "Analysis/src/AutocompleteCore.cpp",
        "Analysis/src/BuiltinDefinitions.cpp",
        "Analysis/src/BuiltinTypeFunctions.cpp",
        "Analysis/src/Clone.cpp",
        "Analysis/src/Constraint.cpp",
        "Analysis/src/ConstraintGenerator.cpp",
        "Analysis/src/ConstraintSolver.cpp",
        "Analysis/src/DataFlowGraph.cpp",
        "Analysis/src/DcrLogger.cpp",
        "Analysis/src/Def.cpp",
        "Analysis/src/EmbeddedBuiltinDefinitions.cpp",
        "Analysis/src/Error.cpp",
        "Analysis/src/ExpectedTypeVisitor.cpp",
        "Analysis/src/FileResolver.cpp",
        "Analysis/src/FragmentAutocomplete.cpp",
        "Analysis/src/Frontend.cpp",
        "Analysis/src/Generalization.cpp",
        "Analysis/src/NativeStackGuard.cpp",
        "Analysis/src/GlobalTypes.cpp",
        "Analysis/src/Instantiation.cpp",
        "Analysis/src/Instantiation2.cpp",
        "Analysis/src/IostreamHelpers.cpp",
        "Analysis/src/IterativeTypeVisitor.cpp",
        "Analysis/src/IterativeTypeFunctionTypeVisitor.cpp",
        "Analysis/src/JsonEmitter.cpp",
        "Analysis/src/Linter.cpp",
        "Analysis/src/LValue.cpp",
        "Analysis/src/Module.cpp",
        "Analysis/src/NonStrictTypeChecker.cpp",
        "Analysis/src/Normalize.cpp",
        "Analysis/src/OverloadResolver.cpp",
        "Analysis/src/Quantify.cpp",
        "Analysis/src/RecursionCounter.cpp",
        "Analysis/src/Refinement.cpp",
        "Analysis/src/RequireTracer.cpp",
        "Analysis/src/Scope.cpp",
        "Analysis/src/Simplify.cpp",
        "Analysis/src/StructuralTypeEquality.cpp",
        "Analysis/src/Substitution.cpp",
        "Analysis/src/Subtyping.cpp",
        "Analysis/src/SubtypingUnifier.cpp",
        "Analysis/src/Symbol.cpp",
        "Analysis/src/TableLiteralInference.cpp",
        "Analysis/src/ToDot.cpp",
        "Analysis/src/TopoSortStatements.cpp",
        "Analysis/src/ToString.cpp",
        "Analysis/src/TxnLog.cpp",
        "Analysis/src/Type.cpp",
        "Analysis/src/TypeArena.cpp",
        "Analysis/src/TypeAttach.cpp",
        "Analysis/src/TypeChecker2.cpp",
        "Analysis/src/TypedAllocator.cpp",
        "Analysis/src/TypeFunction.cpp",
        "Analysis/src/TypeFunctionError.cpp",
        "Analysis/src/TypeFunctionReductionGuesser.cpp",
        "Analysis/src/TypeFunctionRuntime.cpp",
        "Analysis/src/TypeFunctionRuntimeBuilder.cpp",
        "Analysis/src/TypeIds.cpp",
        "Analysis/src/TypeInfer.cpp",
        "Analysis/src/TypeOrPack.cpp",
        "Analysis/src/TypePack.cpp",
        "Analysis/src/TypePath.cpp",
        "Analysis/src/TypeUtils.cpp",
        "Analysis/src/Unifiable.cpp",
        "Analysis/src/Unifier.cpp",
        "Analysis/src/Unifier2.cpp",
        "Analysis/src/UserDefinedTypeFunction.cpp",
    ];

    let vm_sources = [
        "VM/src/lapi.cpp",
        "VM/src/laux.cpp",
        "VM/src/lbaselib.cpp",
        "VM/src/lbitlib.cpp",
        "VM/src/lbuffer.cpp",
        "VM/src/lbuflib.cpp",
        "VM/src/lbuiltins.cpp",
        "VM/src/lcorolib.cpp",
        "VM/src/ldblib.cpp",
        "VM/src/ldebug.cpp",
        "VM/src/ldo.cpp",
        "VM/src/lfunc.cpp",
        "VM/src/lgc.cpp",
        "VM/src/lgcdebug.cpp",
        "VM/src/linit.cpp",
        "VM/src/lmathlib.cpp",
        "VM/src/lmem.cpp",
        "VM/src/lnumprint.cpp",
        "VM/src/lobject.cpp",
        "VM/src/loslib.cpp",
        "VM/src/lperf.cpp",
        "VM/src/lstate.cpp",
        "VM/src/lstring.cpp",
        "VM/src/lstrlib.cpp",
        "VM/src/ltable.cpp",
        "VM/src/ltablib.cpp",
        "VM/src/ltm.cpp",
        "VM/src/ludata.cpp",
        "VM/src/lutf8lib.cpp",
        "VM/src/lveclib.cpp",
        "VM/src/lintlib.cpp",
        "VM/src/lvmexecute.cpp",
        "VM/src/lvmload.cpp",
        "VM/src/lvmutils.cpp",
    ];

    // Diz ao Cargo exatamente qual arquivo do submódulo monitorar individualmente
    for src in common_sources
        .iter()
        .chain(ast_sources.iter())
        .chain(bytecode_sources.iter())
        .chain(compiler_sources.iter())
        .chain(config_sources.iter())
        .chain(analysis_sources.iter())
        .chain(vm_sources.iter())
    {
        println!("cargo:rerun-if-changed={}", luau_dir.join(src).display());
    }

    // =========================================================================
    // Target Unificado: Luau Core Engine + Custom FFI Shim Wrapper
    // =========================================================================
    let mut build = cc::Build::new();
    build
        .cpp(true)
        .flag_if_supported("-std=c++17")
        .flag_if_supported("/std:c++17")
        .flag_if_supported("/MP")
        .include(luau_dir.join("Common/include"))
        .include(luau_dir.join("Ast/include"))
        .include(luau_dir.join("Compiler/include"))
        .include(luau_dir.join("Config/include"))
        .include(luau_dir.join("Bytecode/include"))
        .include(luau_dir.join("VM/include"))
        .include(luau_dir.join("Analysis/include"));

    for src in common_sources {
        build.file(luau_dir.join(src));
    }
    for src in ast_sources {
        build.file(luau_dir.join(src));
    }
    for src in bytecode_sources {
        build.file(luau_dir.join(src));
    }
    for src in compiler_sources {
        build.file(luau_dir.join(src));
    }
    for src in config_sources {
        build.file(luau_dir.join(src));
    }
    for src in analysis_sources {
        build.file(luau_dir.join(src));
    }
    for src in vm_sources {
        build.file(luau_dir.join(src));
    }

    // Custom C++ shim wrapper file unificado no mesmo arquivo estático
    build.file("src/shim.cpp");

    build.compile("luau_analysis");
}
