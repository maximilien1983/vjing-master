// Enveloppe Cast (CAF) : relaie les messages du namespace custom vers le moteur,
// et le feedback du moteur vers le sender. Aucune logique métier ici.
import '@renderer/main';

export const CONTROL_NAMESPACE = 'urn:x-cast:fr.vjm.control';

// Déclaration minimale du SDK CAF (chargé par balise script dans index.html).
declare const cast: {
  framework: {
    CastReceiverContext: {
      getInstance(): {
        addCustomMessageListener(
          namespace: string,
          listener: (event: { senderId: string; data: unknown }) => void,
        ): void;
        sendCustomMessage(namespace: string, senderId: string | undefined, data: unknown): void;
        start(options?: object): void;
      };
    };
  };
};

const context = cast.framework.CastReceiverContext.getInstance();

context.addCustomMessageListener(CONTROL_NAMESPACE, (event) => {
  window.VJM.handleMessage(event.data as never);
});

window.VJM.onFeedback = (msg) => {
  try {
    context.sendCustomMessage(CONTROL_NAMESPACE, undefined, msg);
  } catch (e) {
    console.error('VJM: feedback Cast impossible', e);
  }
};

// Pas de lecture média CAF : on désactive le timeout d'inactivité,
// sinon le receiver est fermé au bout de quelques minutes sans média.
context.start({ disableIdleTimeout: true });
