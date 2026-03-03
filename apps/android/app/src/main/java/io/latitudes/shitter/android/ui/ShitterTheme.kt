package io.latitudes.shitter.android.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.sp
import io.latitudes.shitter.android.R

object ShitterTheme {
    val accent = Color(0xFFB0B0B0)
    val accentStrong = Color(0xFF00FF9C)
    val onAccentStrong = Color.Black
    val textPrimary = Color.White
    val textSecondary = Color(0xFF888888)
    val textMuted = Color(0xFF555555)
    val textBody = Color(0xFFE0E0E0)
    val textSystem = Color(0xFFC6D0CA)
    val surface = Color(0xFF1A1A1A)
    val surfaceLight = Color(0xFF2A2A2A)
    val border = Color(0xFF333333)
    val divider = Color(0xFF1E1E1E)
    val danger = Color(0xFFFF5555)
    val success = Color(0xFF6EA676)
    val warning = Color(0xFFE2A644)
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

    val backgroundBrush: Brush =
        Brush.linearGradient(
            colors =
                listOf(
                    Color(0xFF0A0A0A),
                    Color(0xFF0F0F0F),
                    Color(0xFF080808),
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

private val ShitterColorScheme =
    darkColorScheme(
        primary = ShitterTheme.accent,
        onPrimary = Color(0xFF0D0D0D),
        secondary = ShitterTheme.textSecondary,
        onSecondary = ShitterTheme.textPrimary,
        background = Color.Black,
        onBackground = ShitterTheme.textBody,
        surface = ShitterTheme.surface,
        onSurface = ShitterTheme.textBody,
        error = ShitterTheme.danger,
        onError = Color(0xFF0D0D0D),
        outline = ShitterTheme.border,
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
    MaterialTheme(
        colorScheme = ShitterColorScheme,
        typography = ShitterTypography,
        content = content,
    )
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun ShitterThemePreview() {
    ShitterAppTheme {
        Surface(color = Color.Black) {
            Text(
                text = "Shitter Theme",
                color = MaterialTheme.colorScheme.onBackground,
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}
