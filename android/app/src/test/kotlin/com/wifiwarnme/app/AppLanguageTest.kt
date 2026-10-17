package com.wifiwarnme.app

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class AppLanguageTest {
    @Test
    fun normalizesSupportedCodes() {
        assertEquals("pt", AppLanguage.normalize("pt"))
        assertEquals("pt", AppLanguage.normalize("pt-BR"))
        assertEquals("es", AppLanguage.normalize(" ES "))
        assertEquals("en", AppLanguage.normalize("en_US"))
        assertNull(AppLanguage.normalize("fr"))
        assertNull(AppLanguage.normalize(""))
        assertNull(AppLanguage.normalize(null))
    }

    @Test
    fun systemDefaultFallsBackToPortuguese() {
        assertEquals("es", AppLanguage.fromSystem("es"))
        assertEquals("en", AppLanguage.fromSystem("en"))
        assertEquals("pt", AppLanguage.fromSystem("pt"))
        assertEquals("pt", AppLanguage.fromSystem("de"))
        assertEquals("pt", AppLanguage.fromSystem(null))
    }

    @Test
    fun localeParts() {
        assertEquals("pt" to "BR", AppLanguage.localeParts("pt"))
        assertEquals("es" to "", AppLanguage.localeParts("es"))
        assertEquals("en" to "", AppLanguage.localeParts("en"))
        assertEquals("pt" to "BR", AppLanguage.localeParts("xx"))
    }

    private val res = listOf(File("src/main/res"), File("app/src/main/res")).first { it.isDirectory }

    private fun strings(dir: String): Map<String, String> {
        val document = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(File(res, "$dir/strings.xml"))
        val nodes = document.getElementsByTagName("string")
        return (0 until nodes.length).associate { index ->
            val element = nodes.item(index) as Element
            element.getAttribute("name") to element.textContent
        }
    }

    private fun placeholders(text: String) = Regex("""%\d\$[sd]""").findAll(text).map { it.value }.sorted().toList()

    @Test
    fun everyLanguageHasTheSameKeysAndPlaceholders() {
        val pt = strings("values")
        assertTrue(pt.size > 50)
        for (dir in listOf("values-es", "values-en")) {
            val other = strings(dir)
            assertEquals("keys of $dir", pt.keys, other.keys)
            pt.forEach { (key, text) ->
                assertEquals("placeholders of $key in $dir", placeholders(text), placeholders(other.getValue(key)))
                assertTrue("$key is blank in $dir", other.getValue(key).isNotBlank())
            }
        }
    }

    @Test
    fun everyDiagnosisCodeHasAString() {
        val pt = strings("values")
        DiagnosisCode.values().forEach { assertTrue(it.code, pt.containsKey("diagnosis_${it.code}")) }
    }

    @Test
    fun portugueseResourcesMatchTheCardFixture() {
        val pt = strings("values")
        assertEquals(PT_TEXTS.titleOnline, pt["card_title_online"])
        assertEquals(PT_TEXTS.subtitleSlow, pt["state_label_slow"])
        assertEquals(PT_TEXTS.monitoringPaused, pt["widget_monitoring_paused"])
        // Legacy history mapping uses the same Portuguese texts as the resources.
        DiagnosisCode.values().forEach { code ->
            val text = pt.getValue("diagnosis_${code.code}").replace("%1\$s", "Europa")
            assertEquals(code, DiagnosisCode.fromLegacyText(text))
        }
    }
}
