import streamlit as st
import subprocess
import os
import sys
import logging
from streamlit_autorefresh import st_autorefresh

logging.getLogger('streamlit.runtime.scriptrunner_utils.script_run_context').setLevel(logging.ERROR)
logging.getLogger('streamlit.server.server').setLevel(logging.ERROR)

st.set_page_config(page_title="EMACS Pro", layout="wide")
st.title("🤖 EMACS v5.0 (Gemma-Abliterated Edition)")

col1, col2 = st.columns([1, 2])
with col1:
    if "objective" not in st.session_state: st.session_state.objective = ""
    objective = st.text_area("Objective:", key="input_obj")
    
    if st.button("🚀 Launch"):
        with open("mission_log.txt", "w") as f: f.write("Starting...\n")
        logfile = open("mission_log.txt", "w", encoding="utf-8")
        subprocess.Popen([sys.executable, "-u", "main.py", objective], stdout=logfile, stderr=subprocess.STDOUT)
        st.success("Started!")
        
    st.divider()
    if os.path.exists("workspace"):
        files = os.listdir("workspace")
        if files:
            selected_file = st.selectbox("Select File:", files)
            path = os.path.join("workspace", selected_file)
            if os.path.isfile(path):
                with open(path, "r", encoding="utf-8") as f: st.code(f.read(), language="python")

with col2:
    st.subheader("Logs")
    st_autorefresh(interval=1000, key="logrefresh")
    try:
        with open("mission_log.txt", "r") as f: st.code(f.read())
    except: st.info("No logs.")
