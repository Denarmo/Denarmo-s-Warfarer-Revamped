#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <reframework/API.h>
extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}
#include <cstdio>
REFLuaStateCreatedCb callback{};
bool register_callback(REFLuaStateCreatedCb cb) { callback = cb; return true; }
int main(int argc, char** argv) {
    if (argc != 2) return 1;
    auto dll = LoadLibraryA(argv[1]);
    if (!dll) return 2;
    auto initialize = reinterpret_cast<REFPluginInitializeFn>(GetProcAddress(dll, "reframework_plugin_initialize"));
    if (!initialize) return 3;
    REFrameworkPluginFunctions functions{};
    functions.on_lua_state_created = register_callback;
    REFrameworkPluginInitializeParam param{};
    param.functions = &functions;
    if (!initialize(&param) || !callback) return 4;
    auto state = luaL_newstate();
    luaL_openlibs(state);
    callback(state);
    if (luaL_dostring(state, "assert(warfarer_steam_cloud.read() == 'unavailable'); assert(warfarer_steam_cloud.write('{}') == false)")) {
        std::puts(lua_tostring(state, -1)); return 5;
    }
    lua_close(state);
    FreeLibrary(dll);
    std::puts("PASS: built DLL loads, registers Lua bridge, and falls back safely without Steam");
}
