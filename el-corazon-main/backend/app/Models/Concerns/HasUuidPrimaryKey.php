<?php

namespace App\Models\Concerns;

use Illuminate\Support\Str;

/**
 * Clé primaire UUID (string, non auto-incrémentée).
 *
 * Génère un UUID côté application si aucun n'est fourni, tout en restant
 * compatible avec le `DEFAULT gen_random_uuid()` de Supabase.
 */
trait HasUuidPrimaryKey
{
    public static function bootHasUuidPrimaryKey(): void
    {
        static::creating(function ($model) {
            $key = $model->getKeyName();

            if (empty($model->{$key})) {
                $model->{$key} = (string) Str::uuid();
            }
        });
    }

    public function initializeHasUuidPrimaryKey(): void
    {
        $this->incrementing = false;
        $this->keyType = 'string';
    }
}
