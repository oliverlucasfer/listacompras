package br.com.oliverlucas.lista_compras

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class MinhasListasWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)

        val temLista = widgetData.getBoolean("tem_lista", false)
        val titulo = widgetData.getString("titulo", null).orEmpty()
        val pendentes = widgetData.getInt("pendentes", 0)

        val tituloExibido =
            if (temLista && titulo.isNotBlank()) {
                titulo
            } else {
                context.getString(R.string.widget_sem_lista)
            }
        val pendentesExibido =
            context.resources.getQuantityString(
                R.plurals.widget_pendentes,
                pendentes,
                pendentes,
            )

        val abrirAdicionar =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("minhas-listas://adicionar"),
            )

        appWidgetIds.forEach { appWidgetId ->
            val views =
                RemoteViews(context.packageName, R.layout.widget_minhas_listas).apply {
                    setTextViewText(R.id.widget_titulo, tituloExibido)
                    setTextViewText(R.id.widget_pendentes, pendentesExibido)
                    setOnClickPendingIntent(R.id.widget_minhas_listas_container, abrirAdicionar)
                    setOnClickPendingIntent(R.id.widget_botao_adicionar, abrirAdicionar)
                }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
