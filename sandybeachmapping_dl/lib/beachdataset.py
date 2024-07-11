##################################################
# BEACH PYTORCH DATASET
# Author: Suk Yee Yong
##################################################

from pathlib import Path
from torch.utils.data import Dataset
import glob
import numpy as np
import rasterio
import torch


class BeachDataset(Dataset):
    def __init__(self, image_dir, mask_dir=None, list_image=None, thresh_distance=None):
        self.image_dir = image_dir
        self.mask_dir = mask_dir
        self.list_image = list_image
        if self.list_image is None:
            self.list_image = glob.glob1(image_dir, '*.tif')
            # self.list_mask = glob.glob1(mask_dir, '*.tif')
        self.thresh_distance = thresh_distance
    
    def __len__(self):
        return len(self.list_image)
    
    def __getitem__(self, idx):
        fid = self.list_image[idx].rsplit('.')[0].split('_')[-1]
        with rasterio.open(Path(self.image_dir, self.list_image[idx])) as src:
            image = src.read()
        # For one channel
        if src.count == 1:
            image = np.stack((image[0],)*3, axis=0)
        image = torch.from_numpy(image) / 255.
        mask = []
        if self.mask_dir is not None:
            with rasterio.open(Path(self.mask_dir, self.list_image[idx].replace('image', self.mask_dir.stem))) as src:
                mask = src.read()[0] # Use one channel
            if isinstance(self.thresh_distance, (int, float)):
                mask = np.where(np.isnan(mask) | (mask<self.thresh_distance), 0, 1)
            else:
                mask = np.where(np.isnan(mask) | (mask==0), 0, 1)
            mask = torch.from_numpy(mask)
        return fid, image, mask

