package app.society.shared

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.minus
import kotlinx.datetime.plus

/**
 * Builds the monthly bills for a society. Idempotent: homes that already have a bill
 * for [month] are skipped, so re-running a cycle never creates duplicates.
 */
object BillGenerator {

    fun generate(
        homes: List<Home>,
        existing: List<Bill>,
        month: BillingMonth,
        dueDay: Int,
        newId: () -> String,
        newToken: () -> String,
    ): List<Bill> {
        val alreadyBilled = existing.filter { it.month == month }.mapTo(HashSet()) { it.homeId }
        val dueDate = dueDateFor(month, dueDay)
        return homes
            .filter { it.monthlyAmount > Paise.ZERO && it.id !in alreadyBilled }
            .map { home ->
                Bill(
                    id = newId(),
                    societyId = home.societyId,
                    homeId = home.id,
                    month = month,
                    amount = home.monthlyAmount,
                    status = BillStatus.UNPAID,
                    dueDate = dueDate,
                    publicToken = newToken(),
                )
            }
    }

    /** [dueDay] is clamped to the last day of short months (e.g. 31 in February). */
    fun dueDateFor(month: BillingMonth, dueDay: Int): LocalDate {
        val first = LocalDate(month.year, month.month, 1)
        val lastDay = first.plus(1, DateTimeUnit.MONTH).minus(1, DateTimeUnit.DAY).day
        return LocalDate(month.year, month.month, dueDay.coerceIn(1, lastDay))
    }
}
