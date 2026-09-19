# Quaternius Mech GLB

Drop the Quaternius `.glb` file here (e.g., `mech.glb`) to replace the procedural drone with the rigged model.

The `MechUnit` component loads `/models/mech.glb` via `@react-three/drei`'s `useGLTF`. If the file is missing, it falls back to a procedural stylized drone mesh automatically.
