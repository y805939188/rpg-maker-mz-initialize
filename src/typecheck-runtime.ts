function typecheckRuntimeBindings(): void {
  const pixiVersion: string = PIXI.VERSION;
  const reactorRevision: string = RPG_REACTOR_RUNTIME_REVISION;

  const particleContainerConstructor = PIXI.__v8ParticleContainer;
  const particleConstructor = PIXI.Particle;

  const scene = SceneManager._scene;
  const width: number = Graphics.width;
  const height: number = Graphics.height;
  const ticker = Graphics.app.ticker;

  const terminate = Scene_Map.prototype.terminate;

  void pixiVersion;
  void reactorRevision;
  void particleContainerConstructor;
  void particleConstructor;
  void scene;
  void width;
  void height;
  void ticker;
  void terminate;
}

void typecheckRuntimeBindings;

export {};
