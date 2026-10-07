// Protocole app → moteur, version 1. Voir PROTOCOL.md (source de vérité).

export const PROTOCOL_VERSION = 1;

export interface SceneBackground {
  /// 'camera' : caméra de l'appareil via getUserMedia (webcam en préviz PC,
  /// objectif arrière sur téléphone) — id réservé "camera", pas d'url.
  kind: 'shader' | 'video' | 'camera';
  id: string;
  /// kind 'video' : URL du clip (mp4/webm, servi avec CORS).
  url?: string;
  params?: Record<string, number>;
}

export interface SceneOverlay {
  iid: string; // identifiant d'instance choisi par l'app
  /// Motif shader (voir PROTOCOL.md) — ignoré si kind = 'video'.
  motif?: string;
  /// 'shader' (défaut) | 'video' : boucle VJ sur fond noir, fusion additive.
  kind?: 'shader' | 'video';
  /// kind 'video' : URL de la boucle (mp4 muet, servi avec CORS).
  url?: string;
  x: number; // centre, -1..1
  y: number;
  scale: number; // ~0.1..1
  rot: number; // radians
  pulse: number; // 0..1, force de pulsation sur le beat
}

export interface SceneFilter {
  id: string; // ids documentés dans PROTOCOL.md
  intensity: number; // 0..1 ('hue' : radians)
  /// Pulsation sur le beat, 0..1 : 0 = intensité constante, 1 = l'effet ne
  /// vit que sur les temps (enveloppe du moteur). Absent = 0.
  pulse?: number;
}

export interface SceneTransition {
  kind: 'crossfade' | 'cut';
  beats: number;
}

export interface SceneState {
  background: SceneBackground;
  overlays: SceneOverlay[];
  filters: SceneFilter[];
  transition?: SceneTransition;
}

export interface SceneMsg {
  type: 'scene';
  v?: number;
  state: SceneState;
}

export interface BeatMsg {
  type: 'beat';
  v?: number;
  bpm: number; // 0 = pas de beat détecté
  phase: number; // position dans la mesure de 4 temps, [0, 1)
  t0: number; // epoch ms où `phase` était valable
  offsetMs: number; // calibration : positif = retarder les visuels
  confidence?: number;
}

export interface LevelsMsg {
  type: 'levels';
  v?: number;
  low: number;
  mid: number;
  high: number;
}

export type TriggerId =
  | 'flash'
  | 'drop'
  | 'strobe'
  | 'negative'
  | 'zoom'
  | 'shake'
  | 'echo'
  | 'rewind';

export interface TriggerMsg {
  type: 'trigger';
  v?: number;
  id: TriggerId;
  /// Effets maintenables : true à l'appui, false au relâchement. Un tap
  /// (on puis off rapprochés) garantit l'effet pendant une mesure complète ;
  /// maintenu, l'effet dure jusqu'au relâchement. Absent = tap.
  on?: boolean;
}

export interface ConfigMsg {
  type: 'config';
  v?: number;
  debug?: boolean;
  /// Barre de calibration : flash sur chaque temps extrapolé (offset inclus).
  beatBar?: boolean;
  energy?: number;
  light?: number;
}

export interface PingMsg {
  type: 'ping';
  v?: number;
  t: number;
}

export type InboundMsg = SceneMsg | BeatMsg | LevelsMsg | TriggerMsg | ConfigMsg | PingMsg;

export interface StatsMsg {
  type: 'stats';
  fps: number;
  renderMs: number;
  droppedFrames: number;
  bg: string; // fond actif (aperçus console)
  t: number;
}

export interface PongMsg {
  type: 'pong';
  t: number;
  tr: number;
}

/// Fond vidéo illisible (réseau, CORS, format) : l'app doit bannir ce clip
/// et pousser une autre scène.
export interface BgErrorMsg {
  type: 'bgerror';
  id: string;
  reason: string;
}

export type OutboundMsg = StatsMsg | PongMsg | BgErrorMsg;
