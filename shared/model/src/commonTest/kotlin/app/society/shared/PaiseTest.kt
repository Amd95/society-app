package app.society.shared

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class PaiseTest {
    @Test
    fun formatsWholeAndFractionalAmounts() {
        assertEquals("500.00", Paise.ofRupees(500).toDecimalString())
        assertEquals("12.05", Paise(1205).toDecimalString())
        assertEquals("0.07", Paise(7).toDecimalString())
        assertEquals("-3.50", Paise(-350).toDecimalString())
    }

    @Test
    fun billingMonthRejectsInvalidMonth() {
        assertFailsWith<IllegalArgumentException> { BillingMonth(2027, 13) }
    }

    @Test
    fun billingMonthsOrderChronologically() {
        assert(BillingMonth(2026, 12) < BillingMonth(2027, 1))
        assertEquals("2027-04", BillingMonth(2027, 4).toString())
    }
}
