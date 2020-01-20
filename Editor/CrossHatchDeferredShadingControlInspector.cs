using UnityEngine;
using UnityEditor;
using System.Collections;

namespace M8 {
    [CustomEditor(typeof(CrossHatchDeferredShadingControl))]
    public class CrossHatchDeferredShadingControlInspector : Editor {

        public override void OnInspectorGUI() {
            base.OnInspectorGUI();

            var dat = target as CrossHatchDeferredShadingControl;

            if(GUILayout.Button("Refresh")) {
                dat.Apply();
            }
        }
    }
}