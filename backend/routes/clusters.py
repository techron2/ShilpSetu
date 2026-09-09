"""
Virtual Cluster Routes
Allows artisans to federate into Virtual Clusters to pool production capacity
and fulfill bulk buyer orders with combined capacity badges.
"""
from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client
from datetime import datetime, timezone
import logging

logger = logging.getLogger(__name__)

clusters_bp = Blueprint('clusters', __name__)

_MOCK_CLUSTERS = {
    "cluster_gorakhpur_01": {
        "id": "cluster_gorakhpur_01",
        "name": "Gorakhpur Terracotta Collective",
        "craft_type": "Pottery & Terracotta",
        "region": "Gorakhpur, Uttar Pradesh",
        "description": "Federation of master terracotta sculptors delivering authentic kiln-fired craft.",
        "members": [
            {"artisan_id": "artisan_demo_01", "name": "Ramu Prajapati", "capacity": 450, "role": "Lead Craftsman"},
            {"artisan_id": "test_artisan_phase4", "name": "Pritam Crafts", "capacity": 600, "role": "Master Potter"}
        ],
        "combined_capacity": 1050,
        "active": True,
        "created_at": "2026-01-15T08:00:00Z"
    }
}


@clusters_bp.route('', methods=['POST'])
def create_cluster():
    """
    POST /api/clusters
    Create a new artisan virtual cluster.
    Request body:
        name        (str, required)
        craft_type  (str, required)
        region      (str, required)
        artisan_id  (str, required)
        artisan_name(str, optional)
        capacity    (int, monthly production capacity in units)
        description (str, optional)
    """
    data = request.get_json(silent=True) or {}
    name = data.get('name', '').strip()
    craft_type = data.get('craft_type', '').strip()
    region = data.get('region', '').strip()
    artisan_id = data.get('artisan_id', '').strip()
    artisan_name = data.get('artisan_name', 'Lead Artisan')
    capacity = int(data.get('capacity', 250))
    description = data.get('description', '')

    if not name or not craft_type or not artisan_id:
        return jsonify({"success": False, "error": "name, craft_type, and artisan_id are required"}), 400

    cluster_doc = {
        "name": name,
        "craft_type": craft_type,
        "region": region,
        "description": description or f"Collaborative artisan federation for {craft_type} in {region}",
        "lead_artisan_id": artisan_id,
        "members": [
            {
                "artisan_id": artisan_id,
                "name": artisan_name,
                "capacity": capacity,
                "joined_at": datetime.now(timezone.utc).isoformat(),
                "role": "Founder / Lead"
            }
        ],
        "member_count": 1,
        "combined_capacity": capacity,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "active": True
    }

    db = get_firestore_client()
    if db:
        try:
            doc_ref = db.collection('clusters').document()
            cluster_doc['id'] = doc_ref.id
            doc_ref.set(cluster_doc)

            # Link cluster to user profile
            try:
                db.collection('users').document(artisan_id).update({
                    "cluster_id": doc_ref.id,
                    "cluster_name": name,
                    "cluster_capacity": capacity
                })
            except Exception:
                pass

            return jsonify({"success": True, "source": "firestore", "cluster": cluster_doc}), 201
        except Exception as e:
            logger.error(f"Error creating cluster: {e}")
            return jsonify({"success": False, "error": str(e)}), 500

    cluster_id = f"cluster_{len(_MOCK_CLUSTERS) + 1}"
    cluster_doc['id'] = cluster_id
    _MOCK_CLUSTERS[cluster_id] = cluster_doc
    return jsonify({"success": True, "source": "mock", "cluster": cluster_doc}), 201


@clusters_bp.route('/<cluster_id>/join', methods=['POST'])
def join_cluster(cluster_id):
    """
    POST /api/clusters/<cluster_id>/join
    Join an existing virtual cluster.
    Request body:
        artisan_id   (str, required)
        artisan_name (str, optional)
        capacity     (int, added monthly capacity)
    """
    data = request.get_json(silent=True) or {}
    artisan_id = data.get('artisan_id', '').strip()
    artisan_name = data.get('artisan_name', 'Artisan Member')
    capacity = int(data.get('capacity', 200))

    if not artisan_id:
        return jsonify({"success": False, "error": "artisan_id is required"}), 400

    db = get_firestore_client()
    if db:
        try:
            doc_ref = db.collection('clusters').document(cluster_id)
            snap = doc_ref.get()
            if not snap.exists:
                return jsonify({"success": False, "error": "Cluster not found"}), 404

            cdata = snap.to_dict()
            members = cdata.get('members', [])

            # Check if already joined
            existing = [m for m in members if m.get('artisan_id') == artisan_id]
            if not existing:
                members.append({
                    "artisan_id": artisan_id,
                    "name": artisan_name,
                    "capacity": capacity,
                    "joined_at": datetime.now(timezone.utc).isoformat(),
                    "role": "Artisan Member"
                })
                new_capacity = cdata.get('combined_capacity', 0) + capacity
                doc_ref.update({
                    "members": members,
                    "member_count": len(members),
                    "combined_capacity": new_capacity
                })
                cdata['members'] = members
                cdata['member_count'] = len(members)
                cdata['combined_capacity'] = new_capacity

            # Link cluster to user profile
            try:
                db.collection('users').document(artisan_id).update({
                    "cluster_id": cluster_id,
                    "cluster_name": cdata.get('name'),
                    "cluster_capacity": capacity
                })
            except Exception:
                pass

            cdata['id'] = cluster_id
            return jsonify({"success": True, "source": "firestore", "cluster": cdata}), 200
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500

    cluster = _MOCK_CLUSTERS.get(cluster_id)
    if not cluster:
        return jsonify({"success": False, "error": "Cluster not found"}), 404

    cluster['members'].append({
        "artisan_id": artisan_id,
        "name": artisan_name,
        "capacity": capacity,
        "joined_at": datetime.now(timezone.utc).isoformat(),
        "role": "Artisan Member"
    })
    cluster['combined_capacity'] += capacity
    return jsonify({"success": True, "source": "mock", "cluster": cluster}), 200


@clusters_bp.route('/<cluster_id>', methods=['GET'])
def get_cluster(cluster_id):
    """GET /api/clusters/<cluster_id>"""
    db = get_firestore_client()
    if db:
        try:
            doc = db.collection('clusters').document(cluster_id).get()
            if doc.exists:
                c = doc.to_dict()
                c['id'] = doc.id
                return jsonify({"success": True, "cluster": c}), 200
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500

    cluster = _MOCK_CLUSTERS.get(cluster_id)
    if cluster:
        return jsonify({"success": True, "cluster": cluster}), 200
    return jsonify({"success": False, "error": "Cluster not found"}), 404


@clusters_bp.route('', methods=['GET'])
def list_clusters():
    """GET /api/clusters — List available clusters"""
    db = get_firestore_client()
    if db:
        try:
            docs = db.collection('clusters').where('active', '==', True).stream()
            results = []
            for d in docs:
                c = d.to_dict()
                c['id'] = d.id
                results.append(c)
            if results:
                return jsonify({"success": True, "clusters": results}), 200
        except Exception:
            pass

    return jsonify({"success": True, "clusters": list(_MOCK_CLUSTERS.values())}), 200


@clusters_bp.route('/by-artisan/<artisan_id>', methods=['GET'])
def get_cluster_by_artisan(artisan_id):
    """GET /api/clusters/by-artisan/<artisan_id>"""
    db = get_firestore_client()
    if db:
        try:
            # Check user doc first
            udoc = db.collection('users').document(artisan_id).get()
            if udoc.exists:
                udata = udoc.to_dict()
                cid = udata.get('cluster_id')
                if cid:
                    cdoc = db.collection('clusters').document(cid).get()
                    if cdoc.exists:
                        c = cdoc.to_dict()
                        c['id'] = cdoc.id
                        return jsonify({"success": True, "cluster": c}), 200

            # Scan clusters
            for doc in db.collection('clusters').stream():
                c = doc.to_dict()
                for m in c.get('members', []):
                    if m.get('artisan_id') == artisan_id:
                        c['id'] = doc.id
                        return jsonify({"success": True, "cluster": c}), 200
        except Exception:
            pass

    # Mock lookup
    for c in _MOCK_CLUSTERS.values():
        for m in c.get('members', []):
            if m.get('artisan_id') == artisan_id:
                return jsonify({"success": True, "cluster": c}), 200

    return jsonify({"success": False, "cluster": None, "message": "No cluster found"}), 404
