using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class MaterialProperty
{
   public enum PropertyType
    {
        Float,
        Color
    }
    public PropertyType type;
    public string propertyName;
    public AnimationCurve curve;
    public Gradient gradient;
}
