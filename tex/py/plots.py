import matplotlib.pyplot as plt
import pandas as pd
import numpy as np


# CHAPTER 2 --- functional unit types
fma_server = pd.read_csv('fma_server.csv');
pma_server = pd.read_csv('pma_server.csv');
pmpa_server = pd.read_csv('pmpa_server.csv');
plt.figure()
plt.title("Cycle count for different functional unit types")
plt.plot(fma_server['Size'], fma_server['Cycles']/10, label="FMA")
plt.plot(pma_server['Size'], pma_server['Cycles']/10, label="PMA")
plt.plot(pmpa_server['Size'], pmpa_server['Cycles']/10, label="PMPA")
plt.ylabel("Cycle count")
plt.xlabel("Input vector size")
plt.legend()
plt.savefig("c2_fut.pdf")

# CHAPTER 2 --- functional unit scaling
unbuf_cycles = pd.read_csv('unbuffered.csv');
buf_cycles = pd.read_csv('buffered.csv');
plt.figure()
plt.title("Cycle count for matrix multiplication")
plt.plot(unbuf_cycles['Units'], unbuf_cycles['Peripheral'], label="Peripheral")
plt.plot(unbuf_cycles['Units'], unbuf_cycles['Processor'], label="Processor")
plt.ylabel("Cycle count")
plt.xlabel("Number of Functional Units")
plt.legend()
plt.savefig("c2_fu_unbuf.pdf")

plt.figure()
plt.title("Cycle count for matrix multiplication")
plt.plot(unbuf_cycles['Units'], unbuf_cycles['Processor']-unbuf_cycles['Peripheral'])
plt.ylabel("Cycle count")
plt.xlabel("Number of Functional Units")
plt.savefig("c2_fu_unbuf_lat.pdf")

# CHAPTER 3 --- communication bottleneck 
plt.figure()
plt.title("Latency for software buffered matrix multiplication")
plt.plot(buf_cycles['Units'], buf_cycles['Processor']-buf_cycles['Peripheral'])
plt.ylabel("Lag cycle count")
plt.xlabel("Number of Functional Units")
plt.savefig("c3_fu_soft_buf_lat.pdf")

plt.figure()
plt.title("Cycle count for software buffered matrix multiplication")
plt.plot(buf_cycles['Units'], buf_cycles['Peripheral'], label="Peripheral")
plt.plot(buf_cycles['Units'], buf_cycles['Processor'], label="Processor")
plt.ylabel("Cycle Count")
plt.xlabel("Number of Functional Units")
plt.legend()
plt.savefig("c3_fu_soft_buf.pdf")

plt.figure()
plt.title("Latency for software buffered matrix multiplication")
plt.plot(buf_cycles['Units'], buf_cycles['Processor']-buf_cycles['Peripheral'])
plt.ylabel("Lag cycle count")
plt.xlabel("Number of Functional Units")
plt.savefig("c3_fu_soft_buf_lat.pdf")


# TODO: cycle comparison for unbuffered and buffered

# TODO: Three accelerator types Simulation results.
