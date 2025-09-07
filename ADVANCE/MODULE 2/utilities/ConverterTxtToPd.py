# OSU Benchmark Results Parser for Jupyter Notebook
import pandas as pd
import re
import os
import glob
from typing import Optional, Dict, Any
import matplotlib.pyplot as plt
import seaborn as sns

def parse_osu_results(file_path: str) -> pd.DataFrame:
    """
    Parse OSU MPI benchmark results from a text file and return a pandas DataFrame.
    
    Args:
        file_path (str): Path to the results text file
        
    Returns:
        pd.DataFrame: DataFrame containing the parsed benchmark results
    """
    
    with open(file_path, 'r') as file:
        content = file.read()
    
    # Extract metadata
    metadata = {}
    
    # Extract YAML file name
    yaml_match = re.search(r'Yaml file that si going to be executed : (.+)', content)
    if yaml_match:
        metadata['yaml_file'] = yaml_match.group(1).strip()
    
    # Extract benchmark type and version
    version_match = re.search(r'# OSU MPI (.+) Test (v[\d.]+)', content)
    if version_match:
        metadata['benchmark_type'] = version_match.group(1).strip()
        metadata['version'] = version_match.group(2).strip()
    
    # Extract datatype
    datatype_match = re.search(r'# Datatype: (.+)\.', content)
    if datatype_match:
        metadata['datatype'] = datatype_match.group(1).strip()
    
    # Find the header line
    header_pattern = r'# Size\s+.*'
    header_match = re.search(header_pattern, content)
    
    if not header_match:
        raise ValueError("Could not find the data header in the file")
    
    # Extract column names from header
    header_line = header_match.group(0)
    columns = re.findall(r'(\w+(?:\s+\w+)*(?:\([^)]+\))?)', header_line.replace('#', '').strip())
    
    # Clean up column names
    columns = [col.strip() for col in columns]
    
    # Find data lines (lines that start with numbers)
    data_lines = []
    lines = content.split('\n')
    
    # Start looking for data after the header
    header_found = False
    for line in lines:
        if '# Size' in line:
            header_found = True
            continue
        
        if header_found and re.match(r'^\s*\d+', line):
            # Split the line and convert to appropriate types
            values = line.strip().split()
            if len(values) >= len(columns):
                data_lines.append(values[:len(columns)])
    
    if not data_lines:
        raise ValueError("No data lines found in the file")
    
    # Create DataFrame
    df = pd.DataFrame(data_lines, columns=columns)
    
    # Convert numeric columns
    for col in df.columns:
        try:
            if 'Size' in col:
                df[col] = pd.to_numeric(df[col], errors='coerce').astype('Float32')
            elif 'Iterations' in col:
                df[col] = pd.to_numeric(df[col], errors='coerce').astype('Float32')
            else:
                df[col] = pd.to_numeric(df[col], errors='coerce')
        except Exception as e:
            print(f"Warning: Could not convert column {col} to numeric: {e}")
    
    # Add metadata as attributes to the DataFrame
    for key, value in metadata.items():
        setattr(df, key, value)
    
    # Add source file name
    df.attrs['source_file'] = os.path.basename(file_path)
    
    return df

def load_all_benchmark_results(directory_path: str = ".") -> Dict[str, pd.DataFrame]:
    """
    Load all benchmark result files from a directory.
    
    Args:
        directory_path (str): Path to directory containing result files
        
    Returns:
        Dict[str, pd.DataFrame]: Dictionary with filenames as keys and DataFrames as values
    """
    results = {}
    
    # Find all .txt files
    pattern = os.path.join(directory_path, "*results.txt")
    files = glob.glob(pattern)
    
    for file_path in files:
        try:
            filename = os.path.basename(file_path)
            print(f"Loading {filename}...")
            df = parse_osu_results(file_path)
            results[filename] = df
            print(f"Successfully loaded {filename}")
        except Exception as e:
            print(f"Error loading {filename}: {e}")
    
    return results

def clean_benchmark_df(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean benchmark dataframe by fixing column names.
    """
    # Strip spaces from column names
    df = df.copy()
    df.columns = [c.strip() for c in df.columns]

    # Fix the bad first column name
    for col in df.columns:
        if "size" in col.lower() and "avg" in col.lower():
            df = df.rename(columns={col: "Size"})
    
    return df



