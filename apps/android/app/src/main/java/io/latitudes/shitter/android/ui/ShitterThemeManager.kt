package io.latitudes.shitter.android.ui

import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import org.json.JSONArray
import org.json.JSONObject

private const val THEME_LOG_TAG = "ShitterThemeManager"
private const val UI_PREFERENCES_NAME = "shitter_ui_prefs"
private const val SELECTED_LIGHT_THEME_KEY = "selected_light_theme"
private const val SELECTED_DARK_THEME_KEY = "selected_dark_theme"

enum class ShitterColorThemeType {
    LIGHT,
    DARK,
}

data class ShitterThemeIndexEntry(
    val slug: String,
    val name: String,
    val type: ShitterColorThemeType,
    val accentHex: String,
    val backgroundHex: String,
    val foregroundHex: String,
)

data class ShitterThemeDefinition(
    val name: String,
    val type: ShitterColorThemeType,
    val colors: Map<String, String>,
)

data class ShitterResolvedTheme(
    val slug: String,
    val name: String,
    val type: ShitterColorThemeType,
    val background: Color,
    val surface: Color,
    val surfaceLight: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val textBody: Color,
    val textSystem: Color,
    val accent: Color,
    val accentStrong: Color,
    val border: Color,
    val separator: Color,
    val danger: Color,
    val success: Color,
    val warning: Color,
    val textOnAccent: Color,
    val codeBackground: Color,
) {
    companion object {
        val defaultLight =
            resolve(
                slug = "codex-light",
                definition =
                    ShitterThemeDefinition(
                        name = "Codex Light",
                        type = ShitterColorThemeType.LIGHT,
                        colors =
                            mapOf(
                                "editor.background" to "#FFFFFF",
                                "editor.foreground" to "#0D0D0D",
                                "sideBar.background" to "#FCFCFC",
                                "sideBar.foreground" to "#212121",
                                "activityBar.background" to "#FCFCFC",
                                "textLink.foreground" to "#0169CC",
                                "button.background" to "#0169CC",
                            ),
                    ),
            )

        val defaultDark =
            resolve(
                slug = "codex-dark",
                definition =
                    ShitterThemeDefinition(
                        name = "Codex Dark",
                        type = ShitterColorThemeType.DARK,
                        colors =
                            mapOf(
                                "editor.background" to "#111111",
                                "editor.foreground" to "#FCFCFC",
                                "sideBar.background" to "#131313",
                                "sideBar.foreground" to "#8F8F8F",
                                "activityBar.background" to "#131313",
                                "textLink.foreground" to "#0169CC",
                                "button.background" to "#0169CC",
                            ),
                    ),
            )

        fun resolve(
            slug: String,
            definition: ShitterThemeDefinition,
        ): ShitterResolvedTheme {
            val colors = definition.colors
            val background =
                colorFromHex(
                    colors["editor.background"],
                    fallback = if (definition.type == ShitterColorThemeType.DARK) Color(0xFF111111) else Color.White,
                )
            val foreground =
                colorFromHex(
                    colors["editor.foreground"],
                    fallback = if (definition.type == ShitterColorThemeType.DARK) Color(0xFFFCFCFC) else Color(0xFF0D0D0D),
                )
            val surface =
                colors["sideBar.background"]?.let(::colorFromHex)
                    ?: adjustBrightness(background, if (definition.type == ShitterColorThemeType.DARK) 0.03f else -0.02f)
            val surfaceLight =
                colors["activityBar.background"]?.let(::colorFromHex)
                    ?: adjustBrightness(surface, if (definition.type == ShitterColorThemeType.DARK) 0.04f else -0.03f)
            val accent =
                colors["textLink.foreground"]?.let(::colorFromHex)
                    ?: colors["button.background"]?.let(::colorFromHex)
                    ?: if (definition.type == ShitterColorThemeType.DARK) Color(0xFFB0B0B0) else Color(0xFF4A4A4A)
            val accentStrong =
                colors["button.background"]?.let(::colorFromHex)
                    ?: colors["textLink.foreground"]?.let(::colorFromHex)
                    ?: accent
            val border =
                colors["editorGroup.border"]?.let(::colorFromHex)
                    ?: colors["sideBar.border"]?.let(::colorFromHex)
                    ?: adjustBrightness(surface, if (definition.type == ShitterColorThemeType.DARK) 0.05f else -0.05f)
            val separator =
                colors["panel.border"]?.let(::colorFromHex)
                    ?: adjustBrightness(background, if (definition.type == ShitterColorThemeType.DARK) 0.04f else -0.04f)

            return ShitterResolvedTheme(
                slug = slug,
                name = definition.name,
                type = definition.type,
                background = background,
                surface = surface,
                surfaceLight = surfaceLight,
                textPrimary = foreground,
                textSecondary = colors["sideBar.foreground"]?.let(::colorFromHex) ?: dimColor(foreground, 0.55f),
                textMuted = colors["editorLineNumber.foreground"]?.let(::colorFromHex) ?: dimColor(foreground, 0.35f),
                textBody = dimColor(foreground, 0.88f),
                textSystem = dimColor(foreground, 0.7f),
                accent = accent,
                accentStrong = accentStrong,
                border = border,
                separator = separator,
                danger = if (definition.type == ShitterColorThemeType.DARK) Color(0xFFFF5555) else Color(0xFFD32F2F),
                success = if (definition.type == ShitterColorThemeType.DARK) Color(0xFF6EA676) else Color(0xFF2E7D32),
                warning = if (definition.type == ShitterColorThemeType.DARK) Color(0xFFE2A644) else Color(0xFFE65100),
                textOnAccent = if (brightness(accentStrong) > 0.5f) Color(0xFF0D0D0D) else Color.White,
                codeBackground = background,
            )
        }

        fun brightness(color: Color): Float = (0.299f * color.red) + (0.587f * color.green) + (0.114f * color.blue)

        fun adjustBrightness(
            color: Color,
            amount: Float,
        ): Color =
            Color(
                red = (color.red + amount).coerceIn(0f, 1f),
                green = (color.green + amount).coerceIn(0f, 1f),
                blue = (color.blue + amount).coerceIn(0f, 1f),
                alpha = color.alpha,
            )

        fun dimColor(
            color: Color,
            factor: Float,
        ): Color =
            if (brightness(color) > 0.5f) {
                Color(
                    red = (color.red * factor).coerceIn(0f, 1f),
                    green = (color.green * factor).coerceIn(0f, 1f),
                    blue = (color.blue * factor).coerceIn(0f, 1f),
                    alpha = color.alpha,
                )
            } else {
                val inverse = 1f - factor
                Color(
                    red = (color.red + ((1f - color.red) * inverse)).coerceIn(0f, 1f),
                    green = (color.green + ((1f - color.green) * inverse)).coerceIn(0f, 1f),
                    blue = (color.blue + ((1f - color.blue) * inverse)).coerceIn(0f, 1f),
                    alpha = color.alpha,
                )
            }
    }
}

internal fun colorFromHex(
    hex: String?,
    fallback: Color = Color.Transparent,
): Color {
    val normalized = hex?.trim()?.takeIf { it.isNotEmpty() } ?: return fallback
    return runCatching { Color(android.graphics.Color.parseColor(normalized)) }.getOrElse { fallback }
}

object ShitterThemeManager {
    private val lock = Any()
    private var appContext: Context? = null
    private var initialized = false
    private var definitionCache = LinkedHashMap<String, ShitterThemeDefinition>()
    private var systemIsDark = true

    var lightTheme by mutableStateOf(ShitterResolvedTheme.defaultLight)
        private set

    var darkTheme by mutableStateOf(ShitterResolvedTheme.defaultDark)
        private set

    var activeTheme by mutableStateOf(ShitterResolvedTheme.defaultDark)
        private set

    var themeVersion by mutableIntStateOf(0)
        private set

    var themeIndex by mutableStateOf<List<ShitterThemeIndexEntry>>(emptyList())
        private set

    val lightThemes: List<ShitterThemeIndexEntry>
        get() = themeIndex.filter { it.type == ShitterColorThemeType.LIGHT }

    val darkThemes: List<ShitterThemeIndexEntry>
        get() = themeIndex.filter { it.type == ShitterColorThemeType.DARK }

    val selectedLightSlug: String
        get() = preferences?.getString(SELECTED_LIGHT_THEME_KEY, null) ?: "codex-light"

    val selectedDarkSlug: String
        get() = preferences?.getString(SELECTED_DARK_THEME_KEY, null) ?: "codex-dark"

    private val preferences
        get() = appContext?.getSharedPreferences(UI_PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun initialize(context: Context) {
        synchronized(lock) {
            if (initialized) {
                return
            }
            appContext = context.applicationContext
            themeIndex = loadThemeIndex()
            lightTheme = loadAndResolve(selectedLightSlug) ?: ShitterResolvedTheme.defaultLight
            darkTheme = loadAndResolve(selectedDarkSlug) ?: ShitterResolvedTheme.defaultDark
            activeTheme = if (systemIsDark) darkTheme else lightTheme
            initialized = true
        }
    }

    fun applySystemTheme(isDark: Boolean) {
        systemIsDark = isDark
        val nextTheme = if (isDark) darkTheme else lightTheme
        if (activeTheme.slug != nextTheme.slug || activeTheme.type != nextTheme.type) {
            activeTheme = nextTheme
        }
    }

    fun selectLightTheme(slug: String) {
        preferences?.edit()?.putString(SELECTED_LIGHT_THEME_KEY, slug)?.apply()
        lightTheme = loadAndResolve(slug) ?: ShitterResolvedTheme.defaultLight
        if (!systemIsDark) {
            activeTheme = lightTheme
        }
        themeVersion += 1
    }

    fun selectDarkTheme(slug: String) {
        preferences?.edit()?.putString(SELECTED_DARK_THEME_KEY, slug)?.apply()
        darkTheme = loadAndResolve(slug) ?: ShitterResolvedTheme.defaultDark
        if (systemIsDark) {
            activeTheme = darkTheme
        }
        themeVersion += 1
    }

    private fun loadThemeIndex(): List<ShitterThemeIndexEntry> {
        val context = appContext ?: return emptyList()
        return runCatching {
            context.assets.open("theme-manifest.json").bufferedReader().use { reader ->
                val array = JSONArray(reader.readText())
                buildList(array.length()) {
                    for (index in 0 until array.length()) {
                        val item = array.getJSONObject(index)
                        add(
                            ShitterThemeIndexEntry(
                                slug = item.optString("slug"),
                                name = item.optString("name"),
                                type = item.optString("type").toThemeType(),
                                accentHex = item.optString("accentHex"),
                                backgroundHex = item.optString("backgroundHex"),
                                foregroundHex = item.optString("foregroundHex"),
                            ),
                        )
                    }
                }
            }
        }.onFailure { error ->
            Log.w(THEME_LOG_TAG, "Failed to load theme manifest", error)
        }.getOrDefault(emptyList())
    }

    private fun loadAndResolve(slug: String): ShitterResolvedTheme? {
        val definition = loadDefinition(slug) ?: return null
        return ShitterResolvedTheme.resolve(slug = slug, definition = definition)
    }

    private fun loadDefinition(slug: String): ShitterThemeDefinition? {
        definitionCache[slug]?.let { return it }
        val context = appContext ?: return null
        return runCatching {
            context.assets.open("$slug.json").bufferedReader().use { reader ->
                parseThemeDefinition(JSONObject(reader.readText())).also { parsed ->
                    definitionCache[slug] = parsed
                }
            }
        }.onFailure { error ->
            Log.w(THEME_LOG_TAG, "Failed to load theme $slug", error)
        }.getOrNull()
    }

    private fun parseThemeDefinition(json: JSONObject): ShitterThemeDefinition {
        val colorsJson = json.optJSONObject("colors") ?: JSONObject()
        val colors = LinkedHashMap<String, String>()
        val keys = colorsJson.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            colors[key] = colorsJson.optString(key)
        }
        return ShitterThemeDefinition(
            name = json.optString("name"),
            type = json.optString("type").toThemeType(),
            colors = colors,
        )
    }
}

private fun String.toThemeType(): ShitterColorThemeType =
    if (equals("light", ignoreCase = true)) {
        ShitterColorThemeType.LIGHT
    } else {
        ShitterColorThemeType.DARK
    }
