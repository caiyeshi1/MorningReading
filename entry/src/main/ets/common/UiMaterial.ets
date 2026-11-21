import uiMaterial from '@ohos.arkui.uiMaterial';

/**
 * 沉浸光感材质（API 26）。
 * 目前仅弹窗 / 菜单 / Toast / Slider / Toggle / Select 等系统支持的组件可生效，
 * 普通容器（如自定义浮层）需改为 bindSheet/CustomDialog 才能获得材质。
 */
export function immersiveDialog(): uiMaterial.Material {
  return new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THICK,
    applyShadow: true
  });
}

export function immersiveToast(): uiMaterial.Material {
  return new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    applyShadow: true
  });
}
