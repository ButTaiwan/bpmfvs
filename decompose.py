import sys
import copy
from fontTools.ttLib import TTFont
from fontTools.misc.transform import Transform

def get_component_transform(comp):
    """
    Extracts the affine transformation matrix (a, b, c, d, x, y) from a glyph component.
    """
    # Default values
    scale_x, scale_y = 1.0, 1.0
    a, b, c, d = 1.0, 0.0, 0.0, 1.0
    tx, ty = comp.x, comp.y

    # Check for explicit matrix or scale flags
    if hasattr(comp, 'transform'):
        # comp.transform is usually [[a, b], [c, d]]
        matrix = comp.transform
        a, b = matrix[0]
        c, d = matrix[1]
    
    return Transform(a, b, c, d, tx, ty)

def apply_transform_to_component(comp, t):
    """
    Applies a Transform object (t) to a component.
    """
    # Round translation to nearest integer (TrueType requires integers for x/y)
    comp.x = int(round(t.dx))
    comp.y = int(round(t.dy))
    
    # Store the 2x2 matrix. 
    # If it's identity, we don't strictly need to store it, but for safety in recursion we set it.
    # [ a  b ]
    # [ c  d ]
    comp.transform = [[t.xx, t.xy], [t.yx, t.yy]]
    
    # Flags must be updated to indicate we are using a scale/matrix
    # We force the 'WE_HAVE_A_TWO_BY_TWO' flag strategy implicitly by setting .transform
    # FontTools handles the binary flag packing when saving.

def main():
    if len(sys.argv) < 2:
        print("Usage: python decompose.py <font.ttf>")
        sys.exit(1)

    font_path = sys.argv[1]
    font = TTFont(font_path)
    glyf = font['glyf']
    count = 0

    # Iterate over all glyphs
    for glyph_name in glyf.keys():
        glyph = glyf[glyph_name]
        
        if not glyph.isComposite():
            continue

        # Loop until no components point to composite glyphs
        # We use a while loop because unwrapping one layer might reveal another layer
        while True:
            has_nested = False
            new_components = []
            
            for comp in glyph.components:
                try:
                    target_glyph = glyf[comp.glyphName]
                except KeyError:
                    # Target missing, keep component as is
                    new_components.append(comp)
                    continue

                if target_glyph.isComposite():
                    # FOUND NESTED COMPOSITE
                    has_nested = True
                    
                    # 1. Get the transform of the current component (Parent)
                    parent_transform = get_component_transform(comp)

                    # 2. Iterate through the target's components (Children)
                    for sub_comp in target_glyph.components:
                        # Deep copy the child component so we can modify it
                        new_sub_comp = copy.deepcopy(sub_comp)
                        
                        # 3. Get transform of child
                        child_transform = get_component_transform(sub_comp)
                        
                        # 4. Combine transforms: Parent * Child
                        # The child operates in the parent's coordinate space
                        final_transform = parent_transform.transform(child_transform)
                        
                        # 5. Apply new transform to the new component
                        apply_transform_to_component(new_sub_comp, final_transform)
                        
                        # 6. Add to list
                        new_components.append(new_sub_comp)
                else:
                    # It points to a simple glyph, keep it.
                    new_components.append(comp)

            # Update the glyph's components
            glyph.components = new_components
            
            # If we didn't find any nested composites in this pass, we are done with this glyph
            if not has_nested:
                break
            
            # If we DID find nested composites, we loop again to ensure the *newly added* # components aren't also composites (handling deep recursion)
            count += 1

    if count > 0:
        print(f"Flattened structure of {count} nested composite layers.")
        font.save(font_path)
    else:
        print("No nested components found.")

if __name__ == "__main__":
    main()