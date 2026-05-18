#include "Luau/Frontend.h"
#include "Luau/FileResolver.h"
#include "Luau/Config.h"
#include "Luau/ConfigResolver.h"
#include "Luau/Documentation.h"
#include "Luau/Error.h"
#include "Luau/ToString.h"
#include "Luau/BuiltinDefinitions.h"

#include <string>
#include <vector>
#include <memory>
#include <cstring>
#include <unordered_set>

typedef void (*DiagnosticCallback)(void* context, int severity, unsigned int line, unsigned int col, unsigned int endLine, unsigned int endCol, const char* message);
typedef const char* (*ReadSourceCallback)(void* context, const char* moduleName);
typedef const char* (*ResolveModuleCallback)(void* context, const char* currentModule, const char* requiredName);

struct CustomFileResolver : Luau::FileResolver {
    ReadSourceCallback callback = nullptr;
    ResolveModuleCallback resolveCallback = nullptr;
    void* context = nullptr;

    std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& name) override {
        if (callback) {
            const char* src = callback(context, name.c_str());
            if (src) {
                Luau::SourceCode res;
                res.source = src;
                res.type = Luau::SourceCode::Module;
                return res;
            }
        }
        return std::nullopt;
    }

    std::optional<Luau::ModuleInfo> resolveModule(const Luau::ModuleInfo* contextInfo, Luau::AstExpr* expr, const Luau::TypeCheckLimits& limits) override {
        if (expr) {
            if (auto str = expr->as<Luau::AstExprConstantString>()) {
                std::string req = std::string(str->value.data, str->value.size);
                if (resolveCallback && contextInfo) {
                    const char* resolved = resolveCallback(context, contextInfo->name.c_str(), req.c_str());
                    if (resolved) {
                        Luau::ModuleInfo info;
                        info.name = resolved;
                        info.optional = false;
                        return info;
                    }
                }
                Luau::ModuleInfo info;
                info.name = req;
                info.optional = false;
                return info;
            }
        }
        return std::nullopt;
    }

    std::string getHumanReadableModuleName(const Luau::ModuleName& name) const override {
        return name;
    }
};

struct CustomConfigResolver : Luau::ConfigResolver {
    Luau::Config defaultConfig;

    CustomConfigResolver() {
        defaultConfig.enabledLint.setDefaults();
        defaultConfig.enabledLint.disableWarning(Luau::LintWarning::Code_DeprecatedGlobal);
    }

    const Luau::Config& getConfig(const Luau::ModuleName& name, const Luau::TypeCheckLimits& limits) const override {
        return defaultConfig;
    }
};

struct LuauAnalyzer {
    CustomFileResolver fileResolver;
    CustomConfigResolver configResolver;
    std::unique_ptr<Luau::Frontend> frontend;

    LuauAnalyzer() {
        Luau::FrontendOptions options;
        options.retainFullTypeGraphs = true;
        options.runLintChecks = true;

        frontend = std::make_unique<Luau::Frontend>(Luau::SolverMode::Old, &fileResolver, &configResolver, options);
        Luau::registerBuiltinGlobals(*frontend, frontend->globals);
        addDefinitions(Luau::getBuiltinDefinitionSource().c_str());
    }

    void addDefinitions(const char* source) {
        frontend->loadDefinitionFile(
            frontend->globals,
            frontend->globals.globalScope,
            source,
            "@luks",
            true
        );
    }

    void load(const char* moduleName, ReadSourceCallback readCallback, ResolveModuleCallback resolveCallback, DiagnosticCallback diagCallback, void* context) {
        fileResolver.callback = readCallback;
        fileResolver.resolveCallback = resolveCallback;
        fileResolver.context = context;

        Luau::CheckResult result = frontend->check(moduleName);

        Luau::SourceModule* sm = frontend->getSourceModule(moduleName);
        Luau::Mode mode = sm && sm->mode ? *sm->mode : Luau::Mode::Nonstrict;

        if (diagCallback) {
            for (const Luau::TypeError& err : result.errors) {
                if (err.moduleName == moduleName) {
                    bool isSyntax = Luau::get<Luau::SyntaxError>(err) != nullptr;
                    if (mode == Luau::Mode::NoCheck && !isSyntax) continue;

                    int severity = 0; // Padrão: Erro
                    if (mode != Luau::Mode::Strict && !isSyntax) {
                        severity = 1; // Converte erro de tipo para Warning no modo Nonstrict
                    }

                    std::string msg = Luau::toString(err);
                    diagCallback(context, severity, err.location.begin.line, err.location.begin.column, err.location.end.line, err.location.end.column, msg.c_str());
                }
            }

            if (mode != Luau::Mode::NoCheck) {
                for (const Luau::LintWarning& warn : result.lintResult.errors) {
                    diagCallback(context, 0, warn.location.begin.line, warn.location.begin.column, warn.location.end.line, warn.location.end.column, warn.text.c_str());
                }
                std::unordered_set<unsigned int> seenDeprecatedLines;
                for (const Luau::LintWarning& warn : result.lintResult.warnings) {
                    if (warn.text.find("deprecated") != std::string::npos) {
                        if (seenDeprecatedLines.count(warn.location.begin.line)) continue;
                        seenDeprecatedLines.insert(warn.location.begin.line);
                    }
                    diagCallback(context, 1, warn.location.begin.line, warn.location.begin.column, warn.location.end.line, warn.location.end.column, warn.text.c_str());
                }
            }
        }

        fileResolver.callback = nullptr;
        fileResolver.resolveCallback = nullptr;
        fileResolver.context = nullptr;
    }
};

extern "C" {

LuauAnalyzer* luau_analyzer_create() {
    return new LuauAnalyzer();
}

void luau_analyzer_destroy(LuauAnalyzer* analyzer) {
    delete analyzer;
}

void luau_analyzer_add_definitions(LuauAnalyzer* analyzer, const char* source) {
    if (analyzer && source) {
        analyzer->addDefinitions(source);
    }
}

void luau_analyzer_check(
    LuauAnalyzer* analyzer,
    const char* module_name,
    ReadSourceCallback read_callback,
    ResolveModuleCallback resolve_callback,
    DiagnosticCallback diag_callback,
    void* context
) {
    if (analyzer && module_name) {
        analyzer->load(module_name, read_callback, resolve_callback, diag_callback, context);
    }
}

}
