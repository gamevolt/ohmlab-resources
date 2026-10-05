Here’s a breakdown of why VKD3D doesn’t work:

## :white_check_mark: Steps to Reproduce

1. Create a new container.
2. Select `vkd3d` as the DX wrapper (not even touching the cog icon next to it).
3. Leave all other options untouched.
4. Click **OK** and start the container.

---

## :warning: Observed Behavior

The following code is expected to handle DX wrapper selection:

```java
switch (dxwrapper) {
    case "vkd3d":  // Expected to run when VKD3D is selected
        .... "dxwrapper/dxvk-" + DefaultVersion.DXVK + ".tzst" ,..
        .... "dxwrapper/vkd3d-" + DefaultVersion.VKD3D + ".tzst" ,..
}
```

However, this case is never hit.
- dxwrapper becomes vkd3d- or dxvk-xxx, not the base "vkd3d".
- As a result, it always falls to the default case.

## ⚠ Reason why "vkd3d-" bugging
:jigsaw: Misconfigured Parser Logic

```java
if (dxwrapper.equals("dxvk") || dxwrapper.equals("vkd3d")) {
    this.dxwrapperConfig = DXVKConfigDialog.parseConfig(dxwrapperConfig);
    // VKD3DConfigDialog.parseConfig is never called
}
```

## ⚠ Default Case

```java
//Selecting 2.14 for example for vkd3d will turn it into vkd3d-2.14-0 instead of vkd3d-2.14
//because on setOnConfirmCallback behaviour 

dxvk = version => sVersion.getSelectedItem().toString()
vkd3d = vkd3dVersion => selectedItem.getIdentifier() this add verCode (-0 for default) even on assets version

// By default it trys to install it like this 

.... "dxwrapper/vkd3d-" + "vkd3d-" + ".tzst" // because u dint call VKD3DConfigDialog.parseConfig 
or
.... "dxwrapper/vkd3d-" + "vkd3d-2.14-0" + ".tzst" // if user touch the cog settings and select the built-in vkd3d and presses ok

//both will fail. vkd3d-2.14-0.tzst is not a valid asset for it.
//vkd3d-2.14-0 this -0 version code only used on content one not the built in one on asset
```
# ⚠ Dirty Patch
- this is just temp fix so I wont get alot of merge conflic in the future. I hope you fix this.
- for vkd3d-
```java
 if(dxwrapper.equals("vkd3d-")) dxwrapper = "vkd3d"; // I added this incase its literally just vkd3d-
 switch (dxwrapper) { // so it will install both dxvk and vkd3d by default
  ....
  case "vkd3d":
       Log.d(TAG, "Starting extraction of preinstalled VKD3D files.");
       TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, this, "dxwrapper/dxvk-" + DefaultVersion.DXVK + ".tzst", windowsDir, onExtractFileListener);
       TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, this, "dxwrapper/vkd3d-" + DefaultVersion.VKD3D + ".tzst", windowsDir, onExtractFileListener);
       Log.d(TAG, "Finished extraction of preinstalled VKD3D files.");
       break;
 
// or call the vkd3d parse config
  if (dxwrapper.equals("dxvk")) {
      this.dxwrapperConfig = DXVKConfigDialog.parseConfig(dxwrapperConfig);
  } else if (dxwrapper.equals("vkd3d")) {
      this.dxwrapperConfig = VKD3DConfigDialog.parseConfig(dxwrapperConfig);
  }
```
- for vkd3d-xxx-0
```java
 if (profile != null) {
  ....
 }else{
    Log.d(TAG, "Extracting fallback VKD3D .tzst archive: " + dxwrapper); 
    TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, this, "dxwrapper/dxvk-" + DefaultVersion.DXVK + ".tzst", windowsDir, onExtractFileListener); // this is required 
    TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, this, "dxwrapper/" + dxwrapper.replace("-0","") + ".tzst", windowsDir, onExtractFileListener); // I just remove -0 lol 
```
# ℹ️ Hmm Some stuff I noticed.
vkd3d doesnt work without dxvk on it. on my test.

Maybe you seen that also thats why the default case for vkd3d is 

```java
  case "vkd3d":
       Log.d(TAG, "Starting extraction of preinstalled VKD3D files.");
       TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, this, "dxwrapper/dxvk-" + DefaultVersion.DXVK + ".tzst", windowsDir, onExtractFileListener);
       TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, this, "dxwrapper/vkd3d-" + DefaultVersion.VKD3D + ".tzst", windowsDir, onExtractFileListener);
       Log.d(TAG, "Finished extraction of preinstalled VKD3D files.");
       break;
```

I still have no idea whats the deal with splitting dxvk and vkd3d. 
they dont even control the same dx level. we can have them both by default.

You even reset it when you back at dxvk :'(
```java
 Log.d(TAG, "Extracting DXVK wrapper files, version: " + dxwrapper);
 restoreOriginalDllFiles("d3d12.dll", "d3d12core.dll", "ddraw.dll");
```