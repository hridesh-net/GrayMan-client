import { apiErrorMessage } from '../api/apiClient';
import { workerService } from '../api/workerService';

/**
 * Build a time-lapse from showcase photos and poll until done.
 * @returns {Promise<{ showcaseItemId: string, job: object }>}
 */
export async function compileTimelapse({
  title,
  photoItemIds = [],
  frameDurationSeconds = 0.5,
  onStatus,
}) {
  const build = await workerService.buildTimelapse({
    title,
    photoItemIds,
    frameDurationSeconds,
  });

  const result = await workerService.pollTimelapseJob(build.job_id, {
    onStatus: job => {
      onStatus?.(job.status, job);
    },
  });

  if (result.status === 'failed') {
    throw new Error(result.error || 'Time-lapse compilation failed');
  }

  if (!result.showcase_item_id) {
    throw new Error('Compilation finished without a showcase item');
  }

  return { showcaseItemId: result.showcase_item_id, job: result };
}

export function formatCompileError(err) {
  return apiErrorMessage(err);
}
