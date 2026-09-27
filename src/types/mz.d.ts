declare global {
  const PluginManager: {
    registerCommand(
      pluginName: string,
      commandName: string,
      handler: (args: Record<string, string>) => void
    ): void;
  };

  const SceneManager: {
    _scene: import("pixi.js").Container | null;
  };

  const Graphics: {
    width: number;
    height: number;
    app: import("pixi.js").Application;
  };

  interface Scene_Map {
    terminate(): void;
  }

  const Scene_Map: {
    prototype: Scene_Map;
  };
}

export {};
