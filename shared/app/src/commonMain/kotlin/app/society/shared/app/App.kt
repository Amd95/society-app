package app.society.shared.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import app.society.shared.design.SocietyTheme
import app.society.shared.design.resources.Res
import app.society.shared.design.resources.coming_soon
import app.society.shared.design.resources.tab_complaints
import app.society.shared.design.resources.tab_directory
import app.society.shared.design.resources.tab_dues
import app.society.shared.design.resources.tab_expenses
import app.society.shared.design.resources.tab_notices
import org.jetbrains.compose.resources.StringResource
import org.jetbrains.compose.resources.stringResource

private enum class Tab(val label: StringResource) {
    Dues(Res.string.tab_dues),
    Expenses(Res.string.tab_expenses),
    Complaints(Res.string.tab_complaints),
    Notices(Res.string.tab_notices),
    Directory(Res.string.tab_directory),
}

/** Root composable shared by every platform host. Feature screens replace the placeholders. */
@Composable
fun App() {
    SocietyTheme {
        var selected by rememberSaveable { mutableStateOf(Tab.Dues) }
        Scaffold(
            bottomBar = {
                NavigationBar {
                    Tab.entries.forEach { tab ->
                        NavigationBarItem(
                            selected = tab == selected,
                            onClick = { selected = tab },
                            icon = {},
                            label = { Text(stringResource(tab.label)) },
                        )
                    }
                }
            },
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Text("${stringResource(selected.label)} - ${stringResource(Res.string.coming_soon)}")
            }
        }
    }
}
