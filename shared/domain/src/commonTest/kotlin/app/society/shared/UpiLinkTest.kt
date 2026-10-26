package app.society.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class UpiLinkTest {
    @Test
    fun buildsLinkWithEncodedPayeeAndNote() {
        val link = UpiLink.build(
            payeeVpa = "greenfield@okbank",
            payeeName = "Green Field RWA",
            amount = Paise.ofRupees(500),
            note = "Maintenance 2027-04 B-12",
        )
        assertEquals(
            "upi://pay?pa=greenfield@okbank&pn=Green%20Field%20RWA&am=500.00&cu=INR&tn=Maintenance%202027-04%20B-12",
            link,
        )
    }

    @Test
    fun encodesNonAsciiAsUtf8() {
        val link = UpiLink.build("a@b", "सोसाइटी", Paise(150), "x")
        assertEquals(true, link.contains("pn=%E0%A4%B8"))
    }

    @Test
    fun rejectsBadInput() {
        assertFailsWith<IllegalArgumentException> { UpiLink.build("nohandle", "n", Paise(100), "x") }
        assertFailsWith<IllegalArgumentException> { UpiLink.build("a@b", "n", Paise.ZERO, "x") }
    }
}
