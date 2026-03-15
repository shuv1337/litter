package io.latitudes.shitter.android.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.sp
import io.latitudes.shitter.android.R

object ShitterTheme {
    private val activeTheme: ShitterResolvedTheme
        get() = ShitterThemeManager.activeTheme

    val themeKey: String
        get() = activeTheme.slug

    val isDark: Boolean
        get() = activeTheme.type == ShitterColorThemeType.DARK

    val background: Color
        get() = activeTheme.background

    val accent: Color
        get() = activeTheme.accent

    val accentStrong: Color
        get() = activeTheme.accentStrong

    val onAccentStrong: Color
        get() = activeTheme.textOnAccent

    val textPrimary: Color
        get() = activeTheme.textPrimary

    val textSecondary: Color
        get() = activeTheme.textSecondary

    val textMuted: Color
        get() = activeTheme.textMuted

    val textBody: Color
        get() = activeTheme.textBody

    val textSystem: Color
        get() = activeTheme.textSystem

    val surface: Color
        get() = activeTheme.surface

    val surfaceLight: Color
        get() = activeTheme.surfaceLight

    val border: Color
        get() = activeTheme.border

    val divider: Color
        get() = activeTheme.separator

    val danger: Color
        get() = activeTheme.danger

    val success: Color
        get() = activeTheme.success

    val warning: Color
        get() = activeTheme.warning

    val codeBackground: Color
        get() = activeTheme.codeBackground

    val info = Color(0xFF7CAFD9)
    val violet = Color(0xFFC797D8)
    val amber = Color(0xFFD3A85E)
    val teal = Color(0xFF88C6C7)
    val olive = Color(0xFF9BCF8E)
    val sand = Color(0xFFE3A66F)

    val statusConnecting = warning
    val statusReady = accentStrong
    val statusError = danger
    val statusDisconnected = textMuted

    val toolCallCommand = Color(0xFFC7B072)
    val toolCallFileChange = info
    val toolCallFileDiff = Color(0xFF6FA9D8)
    val toolCallMcpCall = violet
    val toolCallMcpProgress = amber
    val toolCallWebSearch = teal
    val toolCallCollaboration = olive
    val toolCallImage = sand

    val backgroundBrush: Brush
        get() =
            Brush.linearGradient(
            colors =
                listOf(
                    background,
                    ShitterResolvedTheme.adjustBrightness(
                        background,
                        if (isDark) 0.02f else -0.01f,
                    ),
                    ShitterResolvedTheme.adjustBrightness(
                        background,
                        if (isDark) -0.01f else 0.01f,
                    ),
                ),
            )
}

private val Mono =
    FontFamily(
        Font(R.font.berkeley_mono_regular, weight = FontWeight.Normal, style = FontStyle.Normal),
        Font(R.font.berkeley_mono_oblique, weight = FontWeight.Normal, style = FontStyle.Italic),
        Font(R.font.berkeley_mono_bold, weight = FontWeight.Bold, style = FontStyle.Normal),
        Font(R.font.berkeley_mono_bold_oblique, weight = FontWeight.Bold, style = FontStyle.Italic),
    )

private val ShitterTypography =
    Typography(
        titleLarge =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.SemiBold,
                fontSize = 20.sp,
            ),
        titleMedium =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.Medium,
                fontSize = 16.sp,
            ),
        titleSmall =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.Medium,
                fontSize = 14.sp,
            ),
        headlineSmall =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.SemiBold,
                fontSize = 20.sp,
            ),
        bodyLarge =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.Normal,
                fontSize = 16.sp,
            ),
        bodyMedium =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.Normal,
                fontSize = 14.sp,
            ),
        bodySmall =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.Normal,
                fontSize = 12.sp,
            ),
        labelLarge =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.Medium,
                fontSize = 12.sp,
            ),
        labelMedium =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.Medium,
                fontSize = 11.sp,
            ),
        labelSmall =
            TextStyle(
                fontFamily = Mono,
                fontWeight = FontWeight.Medium,
                fontSize = 10.sp,
            ),
    )

@Composable
fun ShitterAppTheme(content: @Composable () -> Unit) {
    val appContext = LocalContext.current.applicationContext
    DisposableEffect(appContext) {
        ShitterThemeManager.initialize(appContext)
        onDispose {}
    }

    val isSystemDark = isSystemInDarkTheme()
    val lightThemeSlug = ShitterThemeManager.lightTheme.slug
    val darkThemeSlug = ShitterThemeManager.darkTheme.slug
    LaunchedEffect(isSystemDark, lightThemeSlug, darkThemeSlug) {
        ShitterThemeManager.applySystemTheme(isSystemDark)
    }

    val activeTheme = ShitterThemeManager.activeTheme
    val colorScheme =
        remember(activeTheme.slug, activeTheme.type) {
            if (activeTheme.type == ShitterColorThemeType.DARK) {
                darkColorScheme(
                    primary = activeTheme.accentStrong,
                    onPrimary = activeTheme.textOnAccent,
                    secondary = activeTheme.textSecondary,
                    onSecondary = activeTheme.textPrimary,
                    background = activeTheme.background,
                    onBackground = activeTheme.textBody,
                    surface = activeTheme.surface,
                    onSurface = activeTheme.textBody,
                    error = activeTheme.danger,
                    onError = activeTheme.textOnAccent,
                    outline = activeTheme.border,
                )
            } else {
                lightColorScheme(
                    primary = activeTheme.accentStrong,
                    onPrimary = activeTheme.textOnAccent,
                    secondary = activeTheme.textSecondary,
                    onSecondary = activeTheme.textPrimary,
                    background = activeTheme.background,
                    onBackground = activeTheme.textBody,
                    surface = activeTheme.surface,
                    onSurface = activeTheme.textBody,
                    error = activeTheme.danger,
                    onError = activeTheme.textOnAccent,
                    outline = activeTheme.border,
                )
            }
        }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = ShitterTypography,
        content = content,
    )
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun ShitterThemePreview() {
    ShitterAppTheme {
        Surface(color = ShitterTheme.background) {
            Text(
                text = "Shitter Theme",
                color = MaterialTheme.colorScheme.onBackground,
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}
