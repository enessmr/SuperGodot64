"""
Blender diagnostic script: checks whether a mesh is bound to an armature correctly.
Run from the .blend file (GUI or headless). It prints findings and suggestions.

Usage (headless):
blender --background path/to/flag.blend --python scripts/blender/diagnose_armature_bind.py
"""

import bpy


def find_armature_from_modifier(mesh_obj):
    for mod in mesh_obj.modifiers:
        if mod.type == 'ARMATURE' and mod.object:
            return mod.object, mod
    return None, None


def report():
    mesh_obj = bpy.context.view_layer.objects.active
    if not mesh_obj or mesh_obj.type != 'MESH':
        # try to find any selected mesh
        for o in bpy.context.selected_objects:
            if o.type == 'MESH':
                mesh_obj = o
                break
    if not mesh_obj:
        print('No active/selected mesh object found. Make the mesh active and re-run.')
        return

    print(f'Mesh object: {mesh_obj.name}')

    arm_obj, arm_mod = find_armature_from_modifier(mesh_obj)
    if arm_obj:
        print(f'Found Armature modifier referencing: {arm_obj.name}')
    else:
        print('No Armature modifier with target found on the mesh.')
        # also check for selected armature
        sel_arm = None
        for o in bpy.context.selected_objects:
            if o.type == 'ARMATURE':
                sel_arm = o
                break
        if sel_arm:
            print(f'But an Armature is selected: {sel_arm.name}. Consider setting the Armature modifier target to it.')
        else:
            print('No Armature selected either. The mesh will not deform without an Armature modifier targeting an Armature object.')

    # list vertex groups and counts
    vgroups = mesh_obj.vertex_groups
    if not vgroups:
        print('Mesh has NO vertex groups. That explains why vertex-group deformation will not work.')
    else:
        print(f'Mesh has {len(vgroups)} vertex groups (showing up to 20):')
        for i, g in enumerate(vgroups):
            if i >= 20:
                print('...')
                break
            print(f'  - {g.name}')

    # if we have an armature, compare bone names
    if arm_obj:
        bone_names = [b.name for b in arm_obj.data.bones]
        missing = []
        for g in vgroups:
            if g.name not in bone_names:
                missing.append(g.name)
        if missing:
            print('Vertex groups that do NOT match any bone name (these will not deform):')
            for n in missing[:50]:
                print('  -', n)
        else:
            print('All vertex group names match bones in the armature.')

    # count nonzero assignments per group
    # build group -> count
    group_count = {g.index: 0 for g in vgroups}
    for v in mesh_obj.data.vertices:
        for g in v.groups:
            group_count.setdefault(g.group, 0)
            if g.weight > 0.0:
                group_count[g.group] += 1

    if vgroups:
        print('Vertex group assignment counts (group name: #verts with weight>0):')
        for g in vgroups:
            cnt = group_count.get(g.index, 0)
            print(f'  - {g.name}: {cnt}')

    # final suggestions
    print('\nSuggestions:')
    if not arm_obj:
        print('- Add an Armature modifier to the mesh and set its Object to the Armature, or select an Armature before running the auto-rig script.')
    if not vgroups:
        print('- Create vertex groups (or re-run auto-assignment script) and ensure weights are assigned.')
    if arm_obj and vgroups:
        print('- Ensure vertex group names exactly match bone names (case-sensitive).')
        print('- Enter Pose Mode on the armature and move a bone; in Weight Paint mode you can visualize influence.')


if __name__ == '__main__':
    report()
