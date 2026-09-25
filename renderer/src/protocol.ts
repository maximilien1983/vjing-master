// Protocole app → moteur, version 1. Voir PROTOCOL.md (source de vérité).

export const PROTOCOL_VERSION = 1;

export interface SceneBackground {
  kind: 'shader' | 'video';
  id: string;
  params?: Record<string, number>;
}

export interface SceneTransition {
  kind: 'crossfade' | 'cut';
  beats: number;
}

export interface SceneState {
  background: SceneBackground;
  overlays: unknown[];
  filters: unknown[];
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
  t: number;
}

export interface PongMsg {
  type: 'pong';
  t: number;
  tr: number;
}

export type OutboundMsg = StatsMsg | PongMsg;
