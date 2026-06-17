"""
Report export controller.
JSON export: all plans (gate via subscription for richer data).
PDF export:  Professional plan only.
"""
import io
import logging
from datetime import datetime, timezone

from flask import Blueprint, request, g, send_file

from app.middleware.auth_middleware import require_auth
from app.middleware.subscription_middleware import require_plan
from app.models import farm_model, notification_model, scan_model
from app.services import insights_service
from app.services.subscription_service import get_plan
from app.views.responses import success_response, error_response

reports_bp = Blueprint('reports', __name__)
_log = logging.getLogger(__name__)


@reports_bp.route('/api/reports/export', methods=['GET'])
@require_auth
def export_report():
    """Return a report payload gated by subscription plan.
    ---
    tags:
      - Reports
    security:
      - Bearer: []
    parameters:
      - in: query
        name: period
        type: string
        default: weekly
    responses:
      200:
        description: Report data
    """
    user_id = str(g.current_user['_id'])
    plan    = get_plan(g.current_user)
    period  = request.args.get('period', 'weekly')

    farms  = [farm_model.serialize(i)         for i in farm_model.get_farms_by_owner(user_id)]
    scans  = [scan_model.serialize(i)         for i in scan_model.get_scans_by_user(user_id, 1, 100)]
    notifs = [notification_model.serialize(i) for i in notification_model.list_notifications(user_id, 100)]
    summary = insights_service.build_dashboard_summary(user_id)

    report = {
        'period':        period,
        'generated_at':  datetime.now(timezone.utc).isoformat(),
        'summary':       summary,
        'farms':         farms,
        'scans':         scans,
        'notifications': notifs,
    }

    if plan == 'professional':
        disease_counts = {}
        for scan in scans:
            dr = scan.get('detection_result') or {}
            d  = dr.get('disease', '')
            if d and not dr.get('is_healthy', True):
                disease_counts[d] = disease_counts.get(d, 0) + 1
        report['disease_trends']    = disease_counts
        report['yield_impact_note'] = (
            'Yield impact varies by disease severity and treatment timing. '
            'Consult your local agronomist for field-specific projections.'
        )

    return success_response({
        'report':   report,
        'filename': 'agrilens-{}-report.json'.format(period),
        'plan':     plan,
    })


@reports_bp.route('/api/reports/pdf', methods=['GET'])
@require_auth
@require_plan('professional')
def export_pdf():
    """Generate and download a PDF farm report. Professional plan required.
    ---
    tags:
      - Reports
    security:
      - Bearer: []
    parameters:
      - in: query
        name: period
        type: string
        default: monthly
    responses:
      200:
        description: PDF file download
      403:
        description: Professional plan required
    """
    user_id = str(g.current_user['_id'])
    period  = request.args.get('period', 'monthly')

    farms   = [farm_model.serialize(i)  for i in farm_model.get_farms_by_owner(user_id)]
    scans   = [scan_model.serialize(i)  for i in scan_model.get_scans_by_user(user_id, 1, 200)]
    summary = insights_service.build_dashboard_summary(user_id)

    try:
        pdf_bytes = _build_pdf(g.current_user, period, farms, scans, summary)
    except Exception as exc:
        _log.exception('PDF generation failed: %s', exc)
        return error_response('PDF generation failed. Please try again.', 500)

    timestamp = datetime.now(timezone.utc).strftime('%Y%m%d')
    filename  = 'agrilens-{}-report-{}.pdf'.format(period, timestamp)

    return send_file(
        io.BytesIO(pdf_bytes),
        mimetype='application/pdf',
        as_attachment=True,
        download_name=filename,
    )


def _build_pdf(user, period, farms, scans, summary):
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import cm
    from reportlab.lib import colors
    from reportlab.platypus import (
        SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
    )

    buf    = io.BytesIO()
    doc    = SimpleDocTemplate(buf, pagesize=A4,
                               leftMargin=2*cm, rightMargin=2*cm,
                               topMargin=2*cm,  bottomMargin=2*cm)
    styles = getSampleStyleSheet()

    GREEN       = colors.HexColor('#2E7D32')
    LIGHT_GREEN = colors.HexColor('#E8F5E9')
    DARK_GREY   = colors.HexColor('#37474F')
    MID_GREY    = colors.HexColor('#78909C')

    h1   = ParagraphStyle('h1',   parent=styles['Heading1'], textColor=GREEN,      fontSize=20, spaceAfter=4)
    h2   = ParagraphStyle('h2',   parent=styles['Heading2'], textColor=DARK_GREY,  fontSize=13, spaceAfter=4,  spaceBefore=12)
    body = ParagraphStyle('body', parent=styles['Normal'],   textColor=DARK_GREY,  fontSize=10, leading=14)
    sm   = ParagraphStyle('sm',   parent=styles['Normal'],   textColor=MID_GREY,   fontSize=8)

    now_str = datetime.now(timezone.utc).strftime('%d %B %Y, %H:%M UTC')
    story   = []

    story.append(Paragraph('AgriLens', h1))
    story.append(Paragraph('Agricultural Disease Report — {}'.format(period.title()), h2))
    story.append(HRFlowable(width='100%', color=GREEN, thickness=2))
    story.append(Spacer(1, 0.3*cm))
    story.append(Paragraph('Prepared for: <b>{}</b>'.format(user.get('name') or 'Farmer'), body))
    story.append(Paragraph('Generated: {}'.format(now_str), sm))
    story.append(Spacer(1, 0.5*cm))

    story.append(Paragraph('Summary', h2))
    total_scans = len(scans)
    diseased    = sum(1 for s in scans if s.get('detection_result') and not s['detection_result'].get('is_healthy', True))
    health_rate = round((1 - diseased / total_scans) * 100) if total_scans else 100

    stats = [
        ['Metric', 'Value'],
        ['Total Scans',        str(total_scans)],
        ['Disease Detections', str(diseased)],
        ['Healthy Scans',      str(total_scans - diseased)],
        ['Plant Health Rate',  '{}%'.format(health_rate)],
        ['Farms Monitored',    str(len(farms))],
    ]
    t = Table(stats, colWidths=[9*cm, 7*cm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), GREEN),
        ('TEXTCOLOR',  (0,0), (-1,0), colors.white),
        ('FONTNAME',   (0,0), (-1,0), 'Helvetica-Bold'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, LIGHT_GREEN]),
        ('GRID',       (0,0), (-1,-1), 0.5, MID_GREY),
        ('FONTSIZE',   (0,0), (-1,-1), 10),
        ('PADDING',    (0,0), (-1,-1), 6),
    ]))
    story.append(t)
    story.append(Spacer(1, 0.5*cm))

    disease_counts = {}
    for scan in scans:
        dr = scan.get('detection_result') or {}
        d  = dr.get('disease', '')
        if d and not dr.get('is_healthy', True):
            disease_counts[d] = disease_counts.get(d, 0) + 1

    if disease_counts:
        story.append(Paragraph('Disease Breakdown', h2))
        rows = [['Disease', 'Count', 'Severity']]
        seen = set()
        for scan in scans:
            dr = scan.get('detection_result') or {}
            d  = dr.get('disease', '')
            if d and d not in seen and not dr.get('is_healthy', True):
                seen.add(d)
                rows.append([d, str(disease_counts.get(d, 0)), dr.get('severity', '-')])
        dt = Table(rows, colWidths=[10*cm, 3*cm, 4*cm])
        dt.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), GREEN),
            ('TEXTCOLOR',  (0,0), (-1,0), colors.white),
            ('FONTNAME',   (0,0), (-1,0), 'Helvetica-Bold'),
            ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, LIGHT_GREEN]),
            ('GRID',       (0,0), (-1,-1), 0.5, MID_GREY),
            ('FONTSIZE',   (0,0), (-1,-1), 9),
            ('PADDING',    (0,0), (-1,-1), 5),
        ]))
        story.append(dt)
        story.append(Spacer(1, 0.5*cm))

    story.append(Paragraph('Recent Scan History (last 10)', h2))
    scan_rows = [['Date', 'Crop', 'Disease', 'Confidence', 'Severity']]
    for scan in scans[:10]:
        dr = scan.get('detection_result') or {}
        scan_rows.append([
            (scan.get('created_at') or '')[:10],
            scan.get('crop_type') or '-',
            dr.get('disease', '-'),
            '{}%'.format(round(dr.get('confidence', 0) * 100)) if dr.get('confidence') else '-',
            dr.get('severity', '-'),
        ])
    st = Table(scan_rows, colWidths=[3*cm, 3*cm, 6*cm, 2.5*cm, 2.5*cm])
    st.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), GREEN),
        ('TEXTCOLOR',  (0,0), (-1,0), colors.white),
        ('FONTNAME',   (0,0), (-1,0), 'Helvetica-Bold'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, LIGHT_GREEN]),
        ('GRID',       (0,0), (-1,-1), 0.5, MID_GREY),
        ('FONTSIZE',   (0,0), (-1,-1), 8),
        ('PADDING',    (0,0), (-1,-1), 4),
    ]))
    story.append(st)
    story.append(Spacer(1, 0.5*cm))

    if farms:
        story.append(Paragraph('Registered Farms', h2))
        for farm in farms:
            story.append(Paragraph('<b>{}</b>'.format(farm.get('name', 'Unnamed Farm')), body))
            story.append(Paragraph(
                'Fields: {} | Crop: {} | Area: {} ha'.format(
                    len(farm.get('fields', [])),
                    farm.get('crop_type') or '-',
                    farm.get('area_hectares') or '-',
                ), sm))
            story.append(Spacer(1, 0.2*cm))

    story.append(Paragraph('General Recommendations', h2))
    for rec in [
        'Scout fields weekly and scan suspicious plants promptly.',
        'Rotate crops each season to reduce soil-borne pathogen buildup.',
        'Maintain proper plant spacing to improve airflow and reduce humidity.',
        'Use certified disease-free seeds and planting material.',
        'Apply treatments early morning or evening to maximise efficacy.',
    ]:
        story.append(Paragraph('- {}'.format(rec), body))
    story.append(Spacer(1, 0.5*cm))

    story.append(HRFlowable(width='100%', color=MID_GREY, thickness=0.5))
    story.append(Paragraph(
        'This report was generated by AgriLens AI. For critical decisions, always consult a certified agronomist.',
        sm))

    doc.build(story)
    return buf.getvalue()
