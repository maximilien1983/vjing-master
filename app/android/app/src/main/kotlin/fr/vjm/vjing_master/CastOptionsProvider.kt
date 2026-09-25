package fr.vjm.vjing_master

import android.content.Context
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider

/**
 * L'App ID vient de res/values/strings.xml (`cast_app_id`). Ce n'est pas un
 * secret ; le remplacer par l'ID fourni par la Cast Developer Console
 * (voir docs/cast-setup.md).
 */
class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions =
        CastOptions.Builder()
            .setReceiverApplicationId(context.getString(R.string.cast_app_id))
            .build()

    override fun getAdditionalSessionProviders(context: Context): MutableList<SessionProvider>? = null
}
