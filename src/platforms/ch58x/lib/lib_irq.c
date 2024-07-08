#include "lib_irq.h"

#include "CH59xBLE_LIB.h"

uint32_t g_LLE_IRQLibHandlerLocation;

void init_lle_irqlibhandlerlocation() {
    g_LLE_IRQLibHandlerLocation = (uint32_t)LLE_IRQLibHandler;
}
