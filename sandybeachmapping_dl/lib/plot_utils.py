##################################################
# PLOT UTILITIES
# Author: Suk Yee Yong
##################################################

import matplotlib.pyplot as plt
import numpy as np


def plot_imagemask(image, mask, fid=None):
    """
    Plot beach image and mask from OSM
    
    Parameters
    ----------
        image: image array with shape (C, H, W) and RGB range 0-1
        mask: mask array with shape (H, W) and RGB range 0-1
        fid: str of FID
    """
    fig, axes = plt.subplots(figsize=(8,4), nrows=1, ncols=2)
    if fid is not None:
        fig.suptitle(f"FID ID: {fid}")
    axes[0].imshow((np.moveaxis(image, 0, -1)*255).astype(np.uint8), cmap='gist_earth')
    axes[1].imshow((mask*255).astype(np.uint8), cmap='binary')
    axes[0].set_title('Image')
    axes[1].set_title('Mask')
    for ax in axes:
        ax.tick_params(axis='both', which='both', bottom=False, left=False, labelbottom=False, labelleft=False)
    plt.show()

