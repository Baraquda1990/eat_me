from io import BytesIO
from pathlib import Path
from uuid import uuid4

from django.core.files.base import ContentFile
from PIL import Image, ImageOps


MAX_UPLOAD_SIZE = 20 * 1024 * 1024  # 20 MB

VARIANTS = {
    "1080": {
        "max_size": 1080,
        "quality": 85,
    },
    "640": {
        "max_size": 640,
        "quality": 82,
    },
    "320": {
        "max_size": 320,
        "quality": 80,
    },
}


def _prepare_image(uploaded_file):
    if uploaded_file.size > MAX_UPLOAD_SIZE:
        raise ValueError("Image is larger than 20 MB.")

    uploaded_file.seek(0)

    image = Image.open(uploaded_file)
    image = ImageOps.exif_transpose(image)

    # WebP supports transparency.
    if image.mode in ("RGBA", "LA") or (
        image.mode == "P" and "transparency" in image.info
    ):
        image = image.convert("RGBA")
    else:
        image = image.convert("RGB")

    return image


def _make_variant(image, max_size, quality):
    result = image.copy()

    # Never upscale.
    if result.width > max_size or result.height > max_size:
        result.thumbnail(
            (max_size, max_size),
            Image.Resampling.LANCZOS,
        )

    output = BytesIO()

    result.save(
        output,
        format="WEBP",
        quality=quality,
        method=6,
    )

    return ContentFile(output.getvalue())


def save_product_image_variants(uploaded_file, storage):
    """
    Returns:
        {
            "image": "uploads/products/uuid_1080.webp",
            "card": "uploads/products/uuid_640.webp",
            "thumb": "uploads/products/uuid_320.webp",
        }
    """

    image = _prepare_image(uploaded_file)

    base_name = uuid4().hex

    saved = {}

    try:
        for variant, options in VARIANTS.items():
            filename = (
                f"uploads/products/"
                f"{base_name}_{variant}.webp"
            )

            content = _make_variant(
                image,
                options["max_size"],
                options["quality"],
            )

            saved_name = storage.save(
                filename,
                content,
            )

            saved[variant] = saved_name

    except Exception:
        # Cleanup if one of R2 uploads failed.
        for name in saved.values():
            try:
                storage.delete(name)
            except Exception:
                pass

        raise

    return {
        "image": saved["1080"],
        "card": saved["640"],
        "thumb": saved["320"],
    }


def product_variant_name(image_name, variant):
    """
    uploads/products/abc_1080.webp
        ->
    uploads/products/abc_640.webp
    """

    if not image_name:
        return ""

    path = Path(image_name)

    stem = path.stem

    if not stem.endswith("_1080"):
        return ""

    base = stem[:-5]

    return str(
        path.with_name(
            f"{base}_{variant}.webp"
        )
    )


def delete_product_image_variants(image_field):
    if not image_field or not image_field.name:
        return

    storage = image_field.storage

    names = {
        image_field.name,
        product_variant_name(image_field.name, "640"),
        product_variant_name(image_field.name, "320"),
    }

    for name in names:
        if not name:
            continue

        try:
            storage.delete(name)
        except Exception:
            pass
