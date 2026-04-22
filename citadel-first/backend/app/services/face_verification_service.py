import io
import logging
from dataclasses import dataclass

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

_facenet_model = None
_mtcnn_detector = None


@dataclass
class FaceVerificationResult:
    is_match: bool
    confidence: float
    distance: float
    selfie_face_detected: bool
    doc_face_detected: bool


def _get_models():
    """Lazily initialise and return (MTCNN, InceptionResnetV1)."""
    global _facenet_model, _mtcnn_detector
    if _facenet_model is None or _mtcnn_detector is None:
        from app.core.config import settings

        from facenet_pytorch import MTCNN, InceptionResnetV1

        device = settings.FACE_NET_DEVICE
        _mtcnn_detector = MTCNN(
            image_size=160,
            margin=0,
            min_face_size=40,
            thresholds=[0.6, 0.7, 0.7],
            select_largest=True,
            device=device,
        )
        _facenet_model = InceptionResnetV1(
            classify=False,
            pretrained="vggface2",
        ).eval().to(device)
        logger.info("FACENET models loaded device=%s", device)
    return _mtcnn_detector, _facenet_model


def _load_image(image_bytes: bytes) -> Image.Image:
    """Decode raw bytes into an RGB PIL Image."""
    img = Image.open(io.BytesIO(image_bytes))
    if img.mode != "RGB":
        img = img.convert("RGB")
    return img


def detect_face_count(image_bytes: bytes) -> int:
    """Return the number of faces detected in the image."""
    mtcnn, _ = _get_models()
    img = _load_image(image_bytes)
    boxes, _ = mtcnn.detect(img)
    if boxes is None:
        return 0
    return len(boxes)


def extract_embedding(image_bytes: bytes) -> np.ndarray | None:
    """Detect a face and extract its 512-dimensional embedding.

    Returns None if no face is detected.
    """
    mtcnn, model = _get_models()
    from app.core.config import settings

    device = settings.FACE_NET_DEVICE
    img = _load_image(image_bytes)
    face_tensor = mtcnn(img)
    if face_tensor is None:
        return None
    face_tensor = face_tensor.unsqueeze(0).to(device)
    with torch_no_grad():
        embedding = model(face_tensor)
    return embedding.detach().cpu().numpy().flatten()


def compare_faces(
    selfie_image_bytes: bytes,
    doc_image_bytes: bytes,
    threshold: float = 0.60,
) -> FaceVerificationResult:
    """Compare a selfie face against a document face.

    Extracts embeddings from both images, computes cosine similarity
    and L2 distance, and returns a match determination.
    """
    selfie_embedding = extract_embedding(selfie_image_bytes)
    doc_embedding = extract_embedding(doc_image_bytes)

    selfie_face_detected = selfie_embedding is not None
    doc_face_detected = doc_embedding is not None

    if not selfie_face_detected or not doc_face_detected:
        return FaceVerificationResult(
            is_match=False,
            confidence=0.0,
            distance=float("inf"),
            selfie_face_detected=selfie_face_detected,
            doc_face_detected=doc_face_detected,
        )

    similarity = _cosine_similarity(selfie_embedding, doc_embedding)
    distance = _l2_distance(selfie_embedding, doc_embedding)

    return FaceVerificationResult(
        is_match=similarity >= threshold,
        confidence=float(similarity),
        distance=float(distance),
        selfie_face_detected=True,
        doc_face_detected=True,
    )


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    dot = np.dot(a, b)
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(dot / (norm_a * norm_b))


def _l2_distance(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.linalg.norm(a - b))


def torch_no_grad():
    """Wrapper to avoid importing torch at module level."""
    import torch

    return torch.no_grad()