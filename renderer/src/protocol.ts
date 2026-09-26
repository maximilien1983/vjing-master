// Protocole app → moteur, version 1. Voir PROTOCOL.md (source de vérité).

export const PROTOCOL_VERSION = 1;

export interface SceneBackground {
  kind: 'shader' | 'video';
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
  id: string; // 'bloom' | 'chroma' | 'posterize' | 'hue' (jalon 2)
  intensity: number; // 0..1 ('hue' : radians)
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

export type TriggerId = 'flash' | 'drop' | 'scene' | 'next' | 'keep';

export interface TriggerMsg {
  type: 'trigger';
  v?: number;
  id: TriggerId;
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
