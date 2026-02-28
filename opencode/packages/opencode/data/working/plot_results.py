import pandas as pd
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import numpy as np

# Load Data
df_joints = pd.read_excel('data/outputs/robotarm_6dof_results_v01.xlsx', sheet_name='Path_Joints')
df_traj = pd.read_excel('data/outputs/robotarm_6dof_results_v01.xlsx', sheet_name='Trajectory_XYZ')

# Setup Plot
fig = plt.figure(figsize=(14, 6))

# Subplot 1: Joint Angles
ax1 = fig.add_subplot(1, 2, 1)
for i in range(1, 7):
    col = f'q{i}'
    ax1.plot(df_joints['Step'], df_joints[col], label=f'Joint {i}')

ax1.set_title('Joint Angles over Time')
ax1.set_xlabel('Step')
ax1.set_ylabel('Angle (rad)')
ax1.legend()
ax1.grid(True)

# Subplot 2: 3D Trajectory
ax2 = fig.add_subplot(1, 2, 2, projection='3d')
sc = ax2.scatter(df_traj['x'], df_traj['y'], df_traj['z'], c=df_traj['Energy_Cost'], cmap='viridis', s=50)
ax2.plot(df_traj['x'], df_traj['y'], df_traj['z'], 'k-', alpha=0.3)

# Add Obstacle (Sphere) for context
u, v = np.mgrid[0:2*np.pi:20j, 0:np.pi:10j]
ox, oy, oz, r = 0.4, 0.2, 0.4, 0.25
x = r * np.cos(u) * np.sin(v) + ox
y = r * np.sin(u) * np.sin(v) + oy
z = r * np.cos(v) + oz
ax2.plot_surface(x, y, z, color='r', alpha=0.3)

ax2.set_title('End-Effector Trajectory (Color: Energy Cost)')
ax2.set_xlabel('X (m)')
ax2.set_ylabel('Y (m)')
ax2.set_zlabel('Z (m)')
plt.colorbar(sc, ax=ax2, label='Inst. Energy Cost')

plt.tight_layout()
output_path = 'data/outputs/robotarm_6dof_plot_v01.png'
plt.savefig(output_path, dpi=300)
print(f"Plot saved to {output_path}")
