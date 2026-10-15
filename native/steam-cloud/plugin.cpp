#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <reframework/API.h>
extern "C" {
#include <lua.h>
#include <lauxlib.h>
}
#include <string>

namespace {
constexpr char filename[] = "WarfarerRevamped/settings-v1.json";
constexpr int max_size = 1024 * 1024;
// Flat Steamworks exports use the C calling convention. Only use the game's
// already loaded Steam API and initialized interfaces; never initialize/shut it down.
struct Storage {
    void* self{};
    bool (__cdecl *exists)(void*, const char*){};
    int (__cdecl *size)(void*, const char*){};
    int (__cdecl *read)(void*, const char*, void*, int){};
    bool (__cdecl *write)(void*, const char*, const void*, int){};
    explicit operator bool() const { return self && exists && size && read && write; }
};
template<class T> T symbol(HMODULE mod, const char* name) {
    return reinterpret_cast<T>(GetProcAddress(mod, name));
}
Storage storage() {
    auto mod = GetModuleHandleW(L"steam_api64.dll");
    if (!mod) return {};
    auto utils_fn = symbol<void* (__cdecl *)()>(mod, "SteamAPI_SteamUtils_v010");
    auto app_id = symbol<unsigned (__cdecl *)(void*)>(mod, "SteamAPI_ISteamUtils_GetAppID");
    auto utils = utils_fn ? utils_fn() : nullptr;
    if (!utils || !app_id || app_id(utils) != 2054970) return {};
    auto get = symbol<void* (__cdecl *)()>(mod, "SteamAPI_SteamRemoteStorage_v016");
    if (!get) get = symbol<void* (__cdecl *)()>(mod, "SteamAPI_SteamRemoteStorage_v014");
    Storage s;
    s.self = get ? get() : nullptr;
    if (!s.self) return {};
    auto account = symbol<bool (__cdecl *)(void*)>(mod, "SteamAPI_ISteamRemoteStorage_IsCloudEnabledForAccount");
    auto app = symbol<bool (__cdecl *)(void*)>(mod, "SteamAPI_ISteamRemoteStorage_IsCloudEnabledForApp");
    if (!account || !app || !account(s.self) || !app(s.self)) return {};
    s.exists = symbol<decltype(s.exists)>(mod, "SteamAPI_ISteamRemoteStorage_FileExists");
    s.size = symbol<decltype(s.size)>(mod, "SteamAPI_ISteamRemoteStorage_GetFileSize");
    s.read = symbol<decltype(s.read)>(mod, "SteamAPI_ISteamRemoteStorage_FileRead");
    s.write = symbol<decltype(s.write)>(mod, "SteamAPI_ISteamRemoteStorage_FileWrite");
    return s;
}
int read_settings(lua_State* L) {
    const auto s = storage();
    if (!s) { lua_pushliteral(L, "unavailable"); return 1; }
    if (!s.exists(s.self, filename)) { lua_pushliteral(L, "missing"); return 1; }
    const int size = s.size(s.self, filename);
    if (size <= 0 || size > max_size) { lua_pushliteral(L, "error"); return 1; }
    std::string bytes(size, '\0');
    if (s.read(s.self, filename, bytes.data(), size) != size) {
        lua_pushliteral(L, "error"); return 1;
    }
    lua_pushliteral(L, "ok");
    lua_pushlstring(L, bytes.data(), bytes.size());
    return 2;
}
int write_settings(lua_State* L) {
    size_t size{};
    const char* bytes = luaL_checklstring(L, 1, &size);
    const auto s = storage();
    lua_pushboolean(L, s && size > 0 && size <= max_size &&
        s.write(s.self, filename, bytes, static_cast<int>(size)));
    return 1;
}
void on_lua(lua_State* L) {
    lua_newtable(L);
    lua_pushcfunction(L, read_settings); lua_setfield(L, -2, "read");
    lua_pushcfunction(L, write_settings); lua_setfield(L, -2, "write");
    lua_setglobal(L, "warfarer_steam_cloud");
}
}
extern "C" __declspec(dllexport) void reframework_plugin_required_version(REFrameworkPluginVersion* v) {
    v->major = REFRAMEWORK_PLUGIN_VERSION_MAJOR;
    v->minor = 0;
    v->patch = 0;
    v->game_name = "DD2";
}
extern "C" __declspec(dllexport) bool reframework_plugin_initialize(const REFrameworkPluginInitializeParam* p) {
    return p->functions->on_lua_state_created(on_lua);
}
