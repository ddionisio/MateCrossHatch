using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace M8 {
    public class CrossHatchDeferredShadingControl : SingletonBehaviour<CrossHatchDeferredShadingControl> {
        public const string shaderPropCrossHatchTexture = "_CrossHatchDeferredTexture";

        public Texture2D crossHatchTexture;

        public void Apply() {
            //setup properties
            Shader.SetGlobalTexture(shaderPropCrossHatchTexture, crossHatchTexture);
        }

        protected override void OnInstanceInit() {
            Apply();
        }
    }
}