import io
import json
import os
import re
import uuid

import streamlit as st

st.set_page_config(
    page_title="Insurance Claims Adjuster",
    page_icon=":house:",
    layout="wide",
)

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DB_SCHEMA = "HOME_DAMAGE_INSPECTION.AERIAL_HOME_IMAGES"
STAGE = f"@{DB_SCHEMA}.PROPERTY_IMAGES_STAGE"
MODEL = "claude-sonnet-4-6"

SEVERITY_COLORS = {
    "NONE": ":green[NONE]",
    "MINOR": ":orange[MINOR]",
    "MODERATE": ":orange[MODERATE]",
    "MAJOR": ":red[MAJOR]",
    "CATASTROPHIC": ":red[CATASTROPHIC]",
}

CONSISTENCY_LABELS = {
    "CONSISTENT": ":green[CONSISTENT]",
    "PARTIALLY_CONSISTENT": ":orange[PARTIALLY CONSISTENT]",
    "INCONSISTENT": ":red[INCONSISTENT]",
    "INSUFFICIENT_EVIDENCE": ":gray[INSUFFICIENT EVIDENCE]",
}

COVERAGE_LABELS = {
    "LIKELY_COVERED": ":green[LIKELY COVERED]",
    "POSSIBLY_COVERED_SUBJECT_TO_REVIEW": ":orange[POSSIBLY COVERED]",
    "LIKELY_EXCLUDED": ":red[LIKELY EXCLUDED]",
    "UNABLE_TO_DETERMINE": ":gray[UNABLE TO DETERMINE]",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _label(mapping, key):
    return mapping.get(key, f":gray[{key or 'N/A'}]")


def parse_ai_response(response):
    if isinstance(response, dict):
        return response
    text = str(response).strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text, flags=re.IGNORECASE).strip()
    text = text.replace("\\n", "\n").replace("\\t", "\t").replace('\\"', '"')
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError(f"AI did not return JSON: {text[:500]}")
    text = text[start : end + 1]
    return json.loads(text)


# ---------------------------------------------------------------------------
# Data loaders (cached)
# ---------------------------------------------------------------------------
@st.cache_data(ttl=60)
def load_dashboard_stats():
    return conn.query(f"""
        SELECT
            COUNT(DISTINCT c.CLAIM_ID)                                      AS TOTAL_CLAIMS,
            COUNT(DISTINCT ci.IMAGE_ID)                                     AS TOTAL_IMAGES,
            COUNT(DISTINCT cf.FINDING_ID)                                   AS TOTAL_FINDINGS,
            COUNT(DISTINCT CASE WHEN cf.SEVERITY IN ('MAJOR','CATASTROPHIC')
                  THEN c.CLAIM_ID END)                                      AS HIGH_SEV_CLAIMS,
            COUNT(DISTINCT CASE WHEN cf.CONSISTENCY_WITH_NARRATIVE = 'INCONSISTENT'
                  THEN c.CLAIM_ID END)                                      AS INCONSISTENT_CLAIMS,
            SUM(c.CLAIMED_LOSS_AMOUNT)                                      AS TOTAL_CLAIMED
        FROM {DB_SCHEMA}.CLAIMS c
        LEFT JOIN {DB_SCHEMA}.CLAIM_IMAGES ci  ON c.CLAIM_ID = ci.CLAIM_ID
        LEFT JOIN {DB_SCHEMA}.CLAIM_FINDINGS cf ON c.CLAIM_ID = cf.CLAIM_ID
    """)


@st.cache_data(ttl=60)
def load_claims_by_state():
    return conn.query(f"""
        SELECT cu.STATE, COUNT(*) AS CLAIM_COUNT
        FROM {DB_SCHEMA}.CLAIMS c
        JOIN {DB_SCHEMA}.CUSTOMERS cu ON c.CUSTOMER_ID = cu.CUSTOMER_ID
        GROUP BY cu.STATE ORDER BY CLAIM_COUNT DESC
    """)


@st.cache_data(ttl=60)
def load_claims_by_cause():
    return conn.query(f"""
        SELECT REPORTED_CAUSE, COUNT(*) AS CNT
        FROM {DB_SCHEMA}.CLAIMS
        GROUP BY REPORTED_CAUSE ORDER BY CNT DESC
    """)


@st.cache_data(ttl=60)
def load_severity_distribution():
    return conn.query(f"""
        SELECT COALESCE(cf.SEVERITY, 'NOT ANALYZED') AS SEVERITY, COUNT(*) AS CNT
        FROM {DB_SCHEMA}.CLAIMS c
        LEFT JOIN {DB_SCHEMA}.CLAIM_FINDINGS cf ON c.CLAIM_ID = cf.CLAIM_ID
        GROUP BY SEVERITY ORDER BY CNT DESC
    """)


@st.cache_data(ttl=60)
def load_claims_queue(statuses, states):
    query = f"""
        SELECT
            c.CLAIM_ID,
            cu.FULL_NAME,
            cu.STATE,
            c.REPORTED_CAUSE,
            c.PERIL_DETAIL,
            c.CLAIMED_LOSS_AMOUNT,
            c.CLAIM_STATUS,
            c.DATE_OF_LOSS,
            COUNT(DISTINCT ci.IMAGE_ID) AS IMAGE_COUNT,
            MAX(cf.SEVERITY) AS MAX_SEVERITY,
            MAX(CASE WHEN cf.CONSISTENCY_WITH_NARRATIVE = 'INCONSISTENT'
                THEN 1 ELSE 0 END) AS HAS_FLAG
        FROM {DB_SCHEMA}.CLAIMS c
        JOIN {DB_SCHEMA}.CUSTOMERS cu ON c.CUSTOMER_ID = cu.CUSTOMER_ID
        LEFT JOIN {DB_SCHEMA}.CLAIM_IMAGES ci ON c.CLAIM_ID = ci.CLAIM_ID
        LEFT JOIN {DB_SCHEMA}.CLAIM_FINDINGS cf ON c.CLAIM_ID = cf.CLAIM_ID
        WHERE 1=1
    """
    params = []
    if statuses:
        placeholders = ", ".join(["?" for _ in statuses])
        query += f" AND c.CLAIM_STATUS IN ({placeholders})"
        params.extend(statuses)
    if states:
        placeholders = ", ".join(["?" for _ in states])
        query += f" AND cu.STATE IN ({placeholders})"
        params.extend(states)
    query += """
        GROUP BY c.CLAIM_ID, cu.FULL_NAME, cu.STATE, c.REPORTED_CAUSE,
                 c.PERIL_DETAIL, c.CLAIMED_LOSS_AMOUNT, c.CLAIM_STATUS, c.DATE_OF_LOSS
        ORDER BY c.DATE_OF_LOSS DESC
    """
    return conn.query(query, params=params)


@st.cache_data(ttl=30)
def load_claim_detail(claim_id):
    return conn.query(
        f"""
        SELECT c.*, cu.FULL_NAME, cu.EMAIL, cu.PHONE, cu.STREET_ADDRESS,
               cu.CITY, cu.STATE, cu.ZIP, cu.POLICY_NUMBER, cu.POLICY_TYPE,
               cu.COVERAGE_LIMIT_DWELLING, cu.DEDUCTIBLE
        FROM {DB_SCHEMA}.CLAIMS c
        JOIN {DB_SCHEMA}.CUSTOMERS cu ON c.CUSTOMER_ID = cu.CUSTOMER_ID
        WHERE c.CLAIM_ID = ?
        """,
        params=[claim_id],
    )


@st.cache_data(ttl=30)
def load_claim_images(claim_id):
    return conn.query(
        f"""
        WITH latest_images AS (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY CLAIM_ID, FILE_NAME
                       ORDER BY UPLOADED_AT DESC
                   ) AS img_rn
            FROM {DB_SCHEMA}.CLAIM_IMAGES
            WHERE CLAIM_ID = ?
        ),
        latest_findings AS (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY IMAGE_ID
                       ORDER BY ANALYZED_AT DESC
                   ) AS find_rn
            FROM {DB_SCHEMA}.CLAIM_FINDINGS
        )
        SELECT ci.IMAGE_ID, ci.FILE_NAME, ci.RELATIVE_PATH, ci.FILE_SIZE_BYTES,
               ci.UPLOADED_AT, ci.PHOTO_ANGLE,
               cf.FINDING_ID, cf.SEVERITY, cf.CONSISTENCY_WITH_NARRATIVE,
               cf.COVERAGE_INDICATION, cf.RECOMMENDED_NEXT_ACTION,
               cf.VISUAL_DESCRIPTION, cf.SUSPECTED_RED_FLAGS,
               cf.COVERAGE_RATIONALE, cf.INCONSISTENCY_NOTES,
               cf.LIKELY_CAUSE_FROM_IMAGE, cf.OBSERVED_DAMAGE_TYPES
        FROM latest_images ci
        LEFT JOIN latest_findings cf
            ON ci.IMAGE_ID = cf.IMAGE_ID AND cf.find_rn = 1
        WHERE ci.img_rn = 1
        ORDER BY ci.UPLOADED_AT
        """,
        params=[claim_id],
    )


@st.cache_data(ttl=30)
def load_claim_options():
    return conn.query(f"""
        SELECT c.CLAIM_ID,
               c.CLAIM_ID || ' - ' || cu.FULL_NAME || ' (' || c.PERIL_DETAIL || ')' AS DISPLAY
        FROM {DB_SCHEMA}.CLAIMS c
        JOIN {DB_SCHEMA}.CUSTOMERS cu ON c.CUSTOMER_ID = cu.CUSTOMER_ID
        ORDER BY c.CLAIM_ID DESC
    """)


@st.cache_data(ttl=30)
def load_open_claim_options():
    return conn.query(f"""
        SELECT c.CLAIM_ID,
               c.CLAIM_ID || ' - ' || cu.FULL_NAME || ' (' || c.PERIL_DETAIL || ')' AS DISPLAY
        FROM {DB_SCHEMA}.CLAIMS c
        JOIN {DB_SCHEMA}.CUSTOMERS cu ON c.CUSTOMER_ID = cu.CUSTOMER_ID
        WHERE c.CLAIM_STATUS IN ('INTAKE', 'NEEDS_PHOTOS', 'UNDER_REVIEW')
        ORDER BY c.CLAIM_ID DESC
    """)


# ---------------------------------------------------------------------------
# Sidebar navigation
# ---------------------------------------------------------------------------
st.sidebar.title(":house: Claims Adjuster")
st.sidebar.caption("AI-powered property damage analysis")

page = st.sidebar.radio(
    "Navigate",
    ["Dashboard", "Claims Queue", "Claim Detail", "Upload & Analyze"],
    label_visibility="collapsed",
)

if st.sidebar.button("Refresh data", use_container_width=True):
    load_dashboard_stats.clear()
    load_claims_by_state.clear()
    load_claims_by_cause.clear()
    load_severity_distribution.clear()
    load_claims_queue.clear()
    load_claim_detail.clear()
    load_claim_images.clear()
    load_claim_options.clear()
    load_open_claim_options.clear()
    st.rerun()

st.sidebar.divider()
st.sidebar.markdown(f"**Model:** `{MODEL}`")


# ===================================================================
# PAGE 1 — Dashboard
# ===================================================================
if page == "Dashboard":
    st.title("Dashboard")

    stats = load_dashboard_stats()
    if stats.empty:
        st.info("No claims data yet. Run the setup SQL scripts first.")
        st.stop()

    row = stats.iloc[0]

    with st.container(horizontal=True):
        st.metric("Total Claims", int(row["TOTAL_CLAIMS"]), border=True)
        st.metric("Total Images", int(row["TOTAL_IMAGES"]), border=True)
        st.metric("Findings", int(row["TOTAL_FINDINGS"]), border=True)
        st.metric(
            "High Severity",
            int(row["HIGH_SEV_CLAIMS"]),
            border=True,
        )
        st.metric(
            "Inconsistent",
            int(row["INCONSISTENT_CLAIMS"]),
            border=True,
        )

    total_claimed = row["TOTAL_CLAIMED"]
    if total_claimed:
        st.metric(
            "Total Claimed Amount",
            f"${total_claimed:,.2f}",
            border=True,
        )

    col1, col2, col3 = st.columns(3)

    with col1:
        with st.container(border=True):
            st.subheader("Claims by State")
            state_df = load_claims_by_state()
            if not state_df.empty:
                st.bar_chart(state_df, x="STATE", y="CLAIM_COUNT")
            else:
                st.write("No data")

    with col2:
        with st.container(border=True):
            st.subheader("Reported Cause")
            cause_df = load_claims_by_cause()
            if not cause_df.empty:
                st.bar_chart(cause_df, x="REPORTED_CAUSE", y="CNT")
            else:
                st.write("No data")

    with col3:
        with st.container(border=True):
            st.subheader("Severity Distribution")
            sev_df = load_severity_distribution()
            if not sev_df.empty:
                st.bar_chart(sev_df, x="SEVERITY", y="CNT")
            else:
                st.write("No data")


# ===================================================================
# PAGE 2 — Claims Queue
# ===================================================================
elif page == "Claims Queue":
    st.title("Claims Queue")

    col1, col2 = st.columns(2)
    with col1:
        status_filter = st.multiselect(
            "Claim Status",
            ["INTAKE", "UNDER_REVIEW", "NEEDS_PHOTOS", "READY_FOR_ADJUSTER"],
            default=[],
        )
    with col2:
        state_filter = st.multiselect(
            "State", ["FL", "CA", "TX", "NY", "OH", "WV"], default=[]
        )

    df = load_claims_queue(
        tuple(status_filter) if status_filter else (),
        tuple(state_filter) if state_filter else (),
    )

    st.dataframe(
        df,
        use_container_width=True,
        column_config={
            "CLAIM_ID": st.column_config.TextColumn("Claim ID", width="small"),
            "FULL_NAME": st.column_config.TextColumn("Customer"),
            "STATE": st.column_config.TextColumn("State", width="small"),
            "REPORTED_CAUSE": st.column_config.TextColumn("Cause"),
            "PERIL_DETAIL": st.column_config.TextColumn("Peril"),
            "CLAIMED_LOSS_AMOUNT": st.column_config.NumberColumn(
                "Claimed ($)", format="$%.2f"
            ),
            "CLAIM_STATUS": st.column_config.TextColumn("Status"),
            "DATE_OF_LOSS": st.column_config.DateColumn("Loss Date"),
            "IMAGE_COUNT": st.column_config.NumberColumn("Images", width="small"),
            "MAX_SEVERITY": st.column_config.TextColumn("Severity"),
            "HAS_FLAG": st.column_config.CheckboxColumn("Flagged?", width="small"),
        },
        hide_index=True,
    )
    st.caption(f"{len(df)} claim(s)")


# ===================================================================
# PAGE 3 — Claim Detail
# ===================================================================
elif page == "Claim Detail":
    st.title("Claim Detail")

    options_df = load_claim_options()
    if options_df.empty:
        st.warning("No claims found.")
        st.stop()

    selected = st.selectbox(
        "Select Claim",
        options_df["CLAIM_ID"].tolist(),
        format_func=lambda x: options_df.loc[
            options_df["CLAIM_ID"] == x, "DISPLAY"
        ].iloc[0],
    )

    if not selected:
        st.stop()

    detail_df = load_claim_detail(selected)
    if detail_df.empty:
        st.warning("Claim not found.")
        st.stop()

    claim = detail_df.iloc[0]

    # -- Customer & Policy card --
    with st.container(border=True):
        st.subheader("Customer & Policy")
        c1, c2, c3 = st.columns(3)
        with c1:
            st.write(f"**Name:** {claim['FULL_NAME'] or 'N/A'}")
            st.write(f"**Phone:** {claim['PHONE'] or 'N/A'}")
            st.write(f"**Email:** {claim['EMAIL'] or 'N/A'}")
        with c2:
            st.write(f"**Address:** {claim['STREET_ADDRESS'] or 'N/A'}")
            st.write(f"**City/State:** {claim['CITY'] or ''}, {claim['STATE'] or ''} {claim['ZIP'] or ''}")
        with c3:
            st.write(f"**Policy:** {claim['POLICY_NUMBER'] or 'N/A'}")
            st.write(f"**Type:** {claim['POLICY_TYPE'] or 'N/A'}")
            st.write(f"**Coverage:** ${claim['COVERAGE_LIMIT_DWELLING']:,.0f}" if claim['COVERAGE_LIMIT_DWELLING'] is not None else "**Coverage:** N/A")
            st.write(f"**Deductible:** ${claim['DEDUCTIBLE']:,.0f}" if claim['DEDUCTIBLE'] is not None else "**Deductible:** N/A")

    # -- Incident info --
    with st.container(border=True):
        st.subheader("Incident Details")
        with st.container(horizontal=True):
            st.metric("Loss Date", str(claim["DATE_OF_LOSS"] or "N/A"), border=True)
            st.metric("Cause", claim["REPORTED_CAUSE"] or "N/A", border=True)
            st.metric("Peril", claim["PERIL_DETAIL"] or "N/A", border=True)
            st.metric("Claimed", f"${claim['CLAIMED_LOSS_AMOUNT']:,.2f}" if claim['CLAIMED_LOSS_AMOUNT'] is not None else "N/A", border=True)
            st.metric("Status", claim["CLAIM_STATUS"], border=True)

        if claim["REPORTED_INCIDENT_NARRATIVE"]:
            st.markdown("**Customer Narrative:**")
            st.info(claim["REPORTED_INCIDENT_NARRATIVE"])

    # -- Images & AI Findings --
    st.subheader("Images & AI Analysis")
    images_df = load_claim_images(selected)

    if images_df.empty:
        st.warning("No images uploaded for this claim. Go to **Upload & Analyze** to add photos.")
    else:
        for idx, img in images_df.iterrows():
            with st.expander(
                f"Image: {img['FILE_NAME'] or 'Unknown'}  —  "
                + ((img["SEVERITY"] or "N/A") if img["FINDING_ID"] else "Not analyzed"),
                expanded=True,
            ):
                if img["RELATIVE_PATH"]:
                    try:
                        img_stream = session.file.get_stream(
                            f"{STAGE}/{img['RELATIVE_PATH']}", decompress=False
                        )
                        st.image(img_stream.read(), use_container_width=True)
                    except Exception:
                        st.caption("Image could not be loaded from stage.")

                if img["FINDING_ID"]:
                    with st.container(horizontal=True):
                        st.metric(
                            "Severity",
                            img["SEVERITY"] or "N/A",
                            border=True,
                        )
                        st.metric(
                            "Consistency",
                            (img["CONSISTENCY_WITH_NARRATIVE"] or "N/A").replace("_", " "),
                            border=True,
                        )
                        st.metric(
                            "Coverage",
                            (img["COVERAGE_INDICATION"] or "N/A").replace("_", " "),
                            border=True,
                        )

                    if img["VISUAL_DESCRIPTION"]:
                        st.markdown(f"**What the AI saw:** {img['VISUAL_DESCRIPTION']}")

                    if img["LIKELY_CAUSE_FROM_IMAGE"]:
                        st.markdown(f"**Likely cause from image:** {img['LIKELY_CAUSE_FROM_IMAGE']}")

                    if img["INCONSISTENCY_NOTES"]:
                        st.warning(f"**Inconsistency notes:** {img['INCONSISTENCY_NOTES']}")

                    if img["SUSPECTED_RED_FLAGS"]:
                        flags = img["SUSPECTED_RED_FLAGS"]
                        if isinstance(flags, str):
                            try:
                                flags = json.loads(flags)
                            except (json.JSONDecodeError, TypeError):
                                pass
                        if isinstance(flags, list) and flags and flags != ["none"]:
                            st.error(f"**Red flags:** {', '.join(str(f) for f in flags)}")

                    if img["COVERAGE_RATIONALE"]:
                        st.markdown(f"**Coverage rationale:** {img['COVERAGE_RATIONALE']}")

                    if img["RECOMMENDED_NEXT_ACTION"]:
                        st.success(f"**Recommended action:** {img['RECOMMENDED_NEXT_ACTION']}")
                else:
                    st.warning("This image has not been analyzed yet.")
                    if st.button(f"Analyze {img['FILE_NAME']}", key=f"analyze_{img['IMAGE_ID']}"):
                        with st.spinner("Running AI analysis..."):
                            try:
                                result = session.sql(
                                    f"CALL {DB_SCHEMA}.ANALYZE_CLAIM_IMAGE(?, ?)",
                                    params=[selected, img["IMAGE_ID"]],
                                ).collect()
                                st.success(result[0][0] if result else "Done")
                                load_claim_images.clear()
                                st.rerun()
                            except Exception as e:
                                st.error(f"Analysis failed: {e}")


# ===================================================================
# PAGE 4 — Upload & Analyze
# ===================================================================
elif page == "Upload & Analyze":
    st.title("Upload & Analyze")
    st.caption("Upload property damage photos and run AI analysis.")

    claims_df = load_open_claim_options()
    if claims_df.empty:
        st.warning("No open claims (INTAKE / NEEDS_PHOTOS / UNDER_REVIEW).")
        st.stop()

    selected_claim = st.selectbox(
        "Select Claim",
        claims_df["CLAIM_ID"].tolist(),
        format_func=lambda x: claims_df.loc[
            claims_df["CLAIM_ID"] == x, "DISPLAY"
        ].iloc[0],
    )

    uploaded_files = st.file_uploader(
        "Upload property damage photos",
        type=["jpg", "jpeg", "png", "webp"],
        accept_multiple_files=True,
    )

    if uploaded_files and selected_claim:
        st.write(f"**{len(uploaded_files)} file(s) selected** for claim `{selected_claim}`")

        if st.button("Upload and Analyze", type="primary"):
            progress = st.progress(0)
            status = st.empty()
            total = len(uploaded_files)

            for i, file in enumerate(uploaded_files):
                status.text(f"Processing {file.name} ({i+1}/{total})...")

                try:
                    # Upload to stage
                    safe_name = re.sub(r"[^A-Za-z0-9._-]", "_", file.name)
                    relative_path = f"claim_images/{selected_claim}/{uuid.uuid4().hex}_{safe_name}"
                    session.file.put_stream(
                        io.BytesIO(file.getvalue()),
                        f"{STAGE}/{relative_path}",
                        auto_compress=False,
                        overwrite=True,
                    )

                    # Create CLAIM_IMAGES record
                    image_id = f"IMG-{uuid.uuid4().hex[:12].upper()}"
                    session.sql(
                        f"""
                        INSERT INTO {DB_SCHEMA}.CLAIM_IMAGES
                            (IMAGE_ID, CLAIM_ID, FILE_NAME, STAGE_PATH, RELATIVE_PATH,
                             FILE_SIZE_BYTES, FILE_TYPE, PHOTO_ANGLE)
                        SELECT ?, ?, ?, ?, ?, ?, ?, ?
                        """,
                        params=[
                            image_id,
                            selected_claim,
                            file.name,
                            f"{STAGE}/{relative_path}",
                            relative_path,
                            file.size,
                            file.type or "image/jpeg",
                            "unspecified",
                        ],
                    ).collect()

                    # Analyze via stored procedure
                    result = session.sql(
                        f"CALL {DB_SCHEMA}.ANALYZE_CLAIM_IMAGE(?, ?)",
                        params=[selected_claim, image_id],
                    ).collect()

                    st.success(f"{file.name}: {result[0][0] if result else 'Done'}")

                except Exception as e:
                    st.error(f"{file.name}: {e}")

                progress.progress((i + 1) / total)

            status.text("All images processed.")

            # Clear caches so other pages reflect new data
            load_claim_images.clear()
            load_claims_queue.clear()
            load_dashboard_stats.clear()
            load_claim_options.clear()
            load_open_claim_options.clear()

            st.info("Navigate to **Claim Detail** to review the AI analysis results.")
